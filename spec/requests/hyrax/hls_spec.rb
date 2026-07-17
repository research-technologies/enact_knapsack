# frozen_string_literal: true

require 'rails_helper'

# Serving the HLS derivative tree through Rails under the file set's own read
# permission. :singletenant because Hyku routing needs a tenant host.
RSpec.describe 'HLS streaming', type: :request, singletenant: true do
  let(:hls_dir) { Hyrax::HlsDerivativeService.directory_for(file_set.id) }

  before do
    FileUtils.mkdir_p(hls_dir)
    File.write(hls_dir.join('index.m3u8'), "#EXTM3U\n#EXT-X-VERSION:4\n")
  end

  after { FileUtils.rm_rf(hls_dir) }

  context 'when the file set is public' do
    let(:file_set) { valkyrie_create(:hyrax_file_set, visibility_setting: 'open') }

    it 'serves the playlist with the HLS content type and forbids CDN caching' do
      get "/file_sets/#{file_set.id}/hls/index.m3u8"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.apple.mpegurl')
      expect(response.body).to include('#EXTM3U')
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'returns 416 for a Range beyond the end of the file' do
      File.binwrite(hls_dir.join('v0_0.ts'), 'abcdefghij')

      get "/file_sets/#{file_set.id}/hls/v0_0.ts", headers: { 'Range' => 'bytes=20-' }

      expect(response).to have_http_status(:range_not_satisfiable)
      expect(response.headers['Content-Range']).to eq('bytes */10')
    end

    it 'answers a Range request with 206 and just the requested bytes' do
      File.binwrite(hls_dir.join('v0_0.ts'), 'abcdefghij')

      get "/file_sets/#{file_set.id}/hls/v0_0.ts", headers: { 'Range' => 'bytes=2-5' }

      expect(response).to have_http_status(:partial_content)
      expect(response.media_type).to eq('video/mp2t')
      expect(response.headers['Content-Range']).to eq('bytes 2-5/10')
      expect(response.body).to eq('cdef')
    end

    it 'returns 404 for a name outside the allowlist' do
      get "/file_sets/#{file_set.id}/hls/secrets.key"

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a path-traversal attempt reaching the guard through the glob' do
      get "/file_sets/#{file_set.id}/hls/..%2f..%2fconfig%2fsecrets.yml"

      expect(response).not_to have_http_status(:ok)
      expect(response.body).not_to include('secret')
    end

    it 'returns 404 when the requested file is not on disk' do
      get "/file_sets/#{file_set.id}/hls/v9.ts"

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the file set is restricted and the request is anonymous' do
    let(:file_set) { valkyrie_create(:hyrax_file_set, visibility_setting: 'restricted') }

    it 'does not serve the file' do
      get "/file_sets/#{file_set.id}/hls/index.m3u8"

      expect(response).not_to have_http_status(:ok)
      expect(response.body).not_to include('#EXTM3U')
    end
  end
end
