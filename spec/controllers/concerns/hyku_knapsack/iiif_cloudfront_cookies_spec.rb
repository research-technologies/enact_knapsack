# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::IiifCloudfrontCookies, type: :controller do
  controller(ActionController::Base) do
    include HykuKnapsack::IiifCloudfrontCookies

    def index
      render plain: 'ok'
    end
  end

  before do
    request.env['HTTPS'] = 'on'
    routes.draw { get 'index' => 'anonymous#index' }
  end

  after { Rails.application.reload_routes! }

  let(:key_pair_id) { 'TESTKEYPAIRID' }
  let(:private_key_b64) { Base64.strict_encode64("-----BEGIN RSA PRIVATE KEY-----\nfake\n-----END RSA PRIVATE KEY-----\n") }
  let(:signed_cookies) do
    {
      'CloudFront-Policy' => 'policy-value',
      'CloudFront-Signature' => 'sig-value',
      'CloudFront-Key-Pair-Id' => key_pair_id
    }
  end
  let(:signer) { instance_double(Aws::CloudFront::CookieSigner, signed_cookie: signed_cookies) }

  before do
    described_class.reset_memoized!
    allow(described_class).to receive(:signer).and_return(signer)
    allow(described_class).to receive(:base_url).and_return('https://iiif.enacthyku.com')
  end

  after { described_class.reset_memoized! }

  shared_context 'with IIIF env vars' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('IIIF_CF_KEY_PAIR_ID').and_return(key_pair_id)
      allow(ENV).to receive(:[]).with('IIIF_CF_PRIVATE_KEY').and_return(private_key_b64)
    end
  end

  shared_context 'without IIIF env vars' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('IIIF_CF_KEY_PAIR_ID').and_return(nil)
      allow(ENV).to receive(:[]).with('IIIF_CF_PRIVATE_KEY').and_return(nil)
    end
  end

  describe '.signer' do
    before do
      described_class.reset_memoized!
      allow(described_class).to receive(:signer).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('IIIF_CF_KEY_PAIR_ID').and_return(key_pair_id)
      allow(ENV).to receive(:[]).with('IIIF_CF_PRIVATE_KEY').and_return(private_key_b64)
      allow(Aws::CloudFront::CookieSigner).to receive(:new).and_return(signer)
    end
    after { described_class.reset_memoized! }

    it 'builds a CookieSigner with the decoded private key' do
      described_class.signer
      expect(Aws::CloudFront::CookieSigner).to have_received(:new).with(
        key_pair_id:,
        private_key: Base64.decode64(private_key_b64)
      )
    end

    it 'memoizes the result' do
      2.times { described_class.signer }
      expect(Aws::CloudFront::CookieSigner).to have_received(:new).once
    end
  end

  describe '.base_url' do
    before do
      described_class.reset_memoized!
      allow(described_class).to receive(:base_url).and_call_original
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('EXTERNAL_IIIF_URL', '').and_return('https://iiif.enacthyku.com/iiif/2')
    end
    after { described_class.reset_memoized! }

    it 'derives the base URL from EXTERNAL_IIIF_URL' do
      expect(described_class.base_url).to eq('https://iiif.enacthyku.com')
    end

    it 'memoizes the result' do
      allow(ENV).to receive(:fetch).with('EXTERNAL_IIIF_URL', '').and_return('https://iiif.enacthyku.com/iiif/2').once
      2.times { described_class.base_url }
    end

    context 'when EXTERNAL_IIIF_URL is invalid' do
      before do
        allow(ENV).to receive(:fetch).with('EXTERNAL_IIIF_URL', '').and_return('not a uri')
        allow(URI).to receive(:parse).and_call_original
        allow(URI).to receive(:parse).with('not a uri').and_raise(URI::InvalidURIError)
      end

      it 'falls back to an empty string' do
        expect(described_class.base_url).to eq('')
      end
    end
  end

  describe 'before_action :set_iiif_cloudfront_cookies' do
    context 'when IIIF CloudFront is configured' do
      include_context 'with IIIF env vars'

      it 'sets all three CloudFront cookies on any request format' do
        get :index, format: :html
        expect(response.cookies['CloudFront-Policy']).to eq('policy-value')
        expect(response.cookies['CloudFront-Signature']).to eq('sig-value')
        expect(response.cookies['CloudFront-Key-Pair-Id']).to eq(key_pair_id)
      end

      it 'also sets cookies on JSON requests so the IIIF viewer manifest fetch refreshes credentials' do
        get :index, format: :json
        expect(response.cookies['CloudFront-Policy']).to eq('policy-value')
        expect(response.cookies['CloudFront-Key-Pair-Id']).to eq(key_pair_id)
      end

      it 'signs cookies using a custom policy so the wildcard Resource is honoured' do
        get :index
        expect(signer).to have_received(:signed_cookie).with(
          'https://iiif.enacthyku.com/*',
          policy: a_string_matching(/"Resource":"https:\/\/iiif\.enacthyku\.com\/\*"/)
        )
      end

      it 'sets cookies with secure, http_only, and SameSite=None so the IIIF viewer can send them cross-origin' do
        get :index
        set_cookie = response.headers['Set-Cookie']
        expect(set_cookie).to match(/\bsecure\b/i)
        expect(set_cookie).to match(/\bhttponly\b/i)
        expect(set_cookie).to match(/SameSite=None/i)
      end

      it 'sets the cookie domain to the root domain' do
        request.host = 'tenant.enact-knapsack-staging.enacthyku.com'
        get :index
        expect(response.headers['Set-Cookie']).to include('domain=.enacthyku.com')
      end

      it 'logs an error and does not raise when signing fails' do
        allow(signer).to receive(:signed_cookie).and_raise(OpenSSL::PKey::RSAError, 'bad key')
        expect(Rails.logger).to receive(:error).with(/bad key/)
        expect { get :index }.not_to raise_error
      end
    end

    context 'when IIIF_CF_KEY_PAIR_ID is not set' do
      include_context 'without IIIF env vars'

      it 'does not call the signer or set any CloudFront cookies' do
        get :index
        expect(described_class).not_to have_received(:signer)
        expect(response.cookies['CloudFront-Policy']).to be_nil
      end
    end

    context 'when IIIF_CF_PRIVATE_KEY is not set' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('IIIF_CF_KEY_PAIR_ID').and_return(key_pair_id)
        allow(ENV).to receive(:[]).with('IIIF_CF_PRIVATE_KEY').and_return(nil)
      end

      it 'does not call the signer or set any CloudFront cookies' do
        get :index
        expect(described_class).not_to have_received(:signer)
        expect(response.cookies['CloudFront-Policy']).to be_nil
      end
    end
  end

  describe '#iiif_cookie_domain' do
    include_context 'with IIIF env vars'

    it 'returns the root domain with a leading dot for a multi-part host' do
      request.host = 'tenant.enact-knapsack-staging.enacthyku.com'
      get :index
      expect(response.headers['Set-Cookie']).to include('domain=.enacthyku.com')
    end

    it 'returns the host as-is for a single-part host like localhost' do
      request.host = 'localhost'
      get :index
      expect(response.headers['Set-Cookie']).to include('domain=localhost')
    end
  end
end
