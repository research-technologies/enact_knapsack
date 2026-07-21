
We wanted to use serverless-iiif for this application, to try to get the best IIIF viewer experience possible. 

Let's use Universal Viewer as our example viewer and follow what happens:

**NOTE**: This part is pretty much true for any Notch8 Hyku implementation
1. A user enters a url for a "show" page in a browser
1. The browser 
   1. Resolves the DNS for the url
   1. Requests the page from the host
1. The network (assume this is always the same every time you go from the browser to the app)
   1. The request from the browser hits the Cloudflare edge
   1. Cloudflare resolves it to our AWS load balancers for the application
   1. The AWS load balancers send it to our cluster's ingress controller (which is our *ingress* nginx)
   1. The ingress controller sends it to the application ingress
   1. The application ingress sends it to our *reverse proxy* nginx
1. The app
   1. The reverse proxy sends the request to the Rails app's Puma server
   1. The Rails app checks authentication, builds the page, etc.
   1. The Puma server sends the response back - in this case the html for the "show" page
1. The browser 
   1. Receives the html from Puma
   1. Starts parsing and rendering the html
   1. Sends off requests for assets from the header, including javascript and css
1. The network (same)
1. The app
   1. The reverse proxy sends back what public assets it can directly, without hitting the Rails app
   1. The reverse proxy sends the rest of the requests to the Rails app's Puma server
   1. The Rails app gets the rest of the assets that the reverse proxy asks for (Hyrax has Rails serve static assets)
1. The browser
   1. Receives the javascript and starts evaluating it. 
   1. Once the browser is done evaluating the javascript in the `</head>` tag, it looks for javascript in the rest of the page
   1. The browser finds the Universal Viewer iFrame and requests the html for Universal Viewer
1. The network (same)
1. The app
   1. Depending on how reverse proxy is set up, either sends back Universal Viewer html directly, or sends the request to the Rails app / Puma to serve
1. The browser
   1. Receives html for Universal Viewer, finds assets in *its* head tag, and requests those assets
1. The network (same)
1. The app (same as last)
1. The browser
  1. Universal Viewer embedded iFrame
     1. Requests the IIIF manifest
1. The network (same)
1. The app
   1. The reverse proxy sends the request to the Puma server, the Rails app generates the manifest on the fly and sends it back. In this case the iiif manifest uses the application's host as its own host, even though we're using serverless-iiif
1. The browser
   1. Universal Viewer embedded iFrame
      1. Receives the IIIF manifest, based on response requests a bunch more javascript in order to be able to render response
1. The network (same)
1. The app
   1. Depending on how reverse proxy is set up, either sends back Universal Viewer html directly, or sends the request to the Rails app / Puma to serve
1. The browser
   1. Universal Viewer embedded iFrame
      1. Receives javascript
      1. Based on IIIF manifest & javascript, requests the first info.json for an image in the manifest, as well as the thumbnail image
1. The network (same - which is notable because we're using serverless-iiif, which would usually be a different hostname)
1. The app **The auth part starts!**
   1. Reverse proxy
      1. Request for a path containing `/iiif` hits the reverse proxy, and the `location ^~  /iiif` block catches it
      1. The `location ^~  /iiif` sends the request for authorization in the `location = /auth` block in the reverse proxy
      1. The `location = /auth` path is *only* available from within the reverse proxy pod (it's `internal`), and it passes the request along to the rails_app web pod on the `/check-iiif` path. The reverse proxy has to capture and pass along a lot of the headers to ensure it can route to the correct tenant.
   1. Rails app
      1. The `/check-iiif` path routes to the Enact IiifController show method. This method checks for the FileSet ID in the `X-Origin-URI` set by the reverse proxy
      1. The Rails app has its own `Enact::IiifAuthorizationService` which mirrors the `Hyrax::IiifAuthorizationService` used by Riiif, it just gets the FileSet ID out differently, since the file paths look different. It uses the same `.can?` method that inherits all of Hyrax and Hyku's authorization checking behaviors.
      1. SUCCESS: If the user is authorized to see the resource, the app sends a success message to the reverse proxy
      1. FAILURE: If the user is *not* authorized to see the resource, the app sends an unauthorized message to the reverse proxy, which 
   1. SUCCESS: Reverse proxy
      1. Sends the request on to the host for the iiif service (e.g. iiif-staging.enacthyku.com), and adds the X-Origin-Verify secret in order to be authorized with Cloudfront. This header is only sent internally from the reverse proxy, never via a browser.
   1. FAILURE: Reverse proxy
      1. Sends the unauthorized message back to the browser
1. Assume from here we're on the SUCCESS path
1. The network (finally something new!)
   1. DNS lookup for iiif-staging.enacthyku.com (different from our main host)
   1. Resolves to Cloudflare, which sends it to the Cloudfront service
   1. The Cloudfront service does some caching, and makes sure that the request has the proper `X-Origin-Verify` secret. If it does, it sends it to the IIIF Lambda url. This url *only* accepts requests from its Cloudfront service
1. The IIIF AWS Lambda 
   1. gets info from the S3 bucket where the images are stored 
   1. Builds and returns an appropriate info.json for the requested image to the browser
   1. This info.json uses the same host as the one that was sent in the request from the reverse proxy, not its own Cloudfront hostname
1. The browser
   1. Universal Viewer embedded iFrame
      1. Based on the info.json for the image, fires a bunch of requests for different sizes of the image.

      Each of image requests goes through each step from "The auth part starts" again. Future work is to make it so that once a given user has been authenticated for a given work, that response is cached for some time, so each IIIF request doesn't have to go through the entire Rails auth flow again and take up Puma threads (which we've found to be a limiting factor in the past).




**NOTE**: We have two "nginx"s in our stack:
* One nginx is used on the cluster level to receive requests from the AWS load balancers and send them to the correct application on the cluster. We call this one the *Ingress*.
* One nginx is used on the application level to receive requests from the Ingress, serve static assets, do additional bot blocking, and caching. We call this on the *Reverse proxy*
