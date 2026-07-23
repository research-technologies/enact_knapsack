# frozen_string_literal: true

module Hyrax
  # Serves the HLS tree under the file set's own read permission. Playlists use
  # relative paths, so every segment request re-enters here and is re-authorized.
  class HlsController < ApplicationController
    # Every valid name in an HLS tree; also the path-traversal guard.
    ALLOWED_FILE = /\A(index\.m3u8|v\d+\.m3u8|v\d+_\d+\.ts)\z/

    def show
      file_set = Hyrax.query_service.find_by(id: params[:id])
      authorize! :read, file_set

      name = params[:path].to_s
      return head(:not_found) unless name.match?(ALLOWED_FILE)

      path = Hyrax::HlsDerivativeService.directory_for(file_set.id).join(name)
      return head(:not_found) unless File.exist?(path)

      response.headers['Cache-Control'] = 'no-store'
      stream(path.to_s, content_type_for(name))
    rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
      head :not_found
    end

    private

    def content_type_for(name)
      case File.extname(name)
      when '.m3u8' then Hyrax::HlsDerivativeService::PLAYLIST_CONTENT_TYPE
      when '.ts'   then 'video/mp2t'
      end
    end

    # Range-aware: full GETs stream from disk via send_file; ranges read just the
    # requested slice into memory (send_file alone would not answer 206).
    def stream(path, type)
      response.headers['Accept-Ranges'] = 'bytes'
      match = request.get_header('HTTP_RANGE')&.match(/bytes=(\d+)-(\d*)/)
      return send_file(path, type:, disposition: 'inline') unless match

      send_range(path, type, match)
    end

    def send_range(path, type, match)
      size = File.size(path)
      from = match[1].to_i
      to = match[2].present? ? [match[2].to_i, size - 1].min : size - 1
      if from >= size || from > to
        response.headers['Content-Range'] = "bytes */#{size}"
        return head(:range_not_satisfiable)
      end
      response.headers['Content-Range'] = "bytes #{from}-#{to}/#{size}"
      response.status = 206
      send_data(IO.binread(path, to - from + 1, from), type:, disposition: 'inline')
    end
  end
end
