# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to stream Range responses in chunks instead of
# loading the requested range (and everything before it) into memory

module Hyrax
  module ValkyrieDownloadsControllerBehaviorDecorator
    CHUNK_SIZE = 1.megabyte

    private

    def send_range_valkyrie(file:)
      from, length = prepare_range_headers_valkyrie(file:)
      io = file.stream
      seek_valkyrie(io:, from:)
      # the enumerator's ensure does not run when a client disconnect
      # abandons the iteration, so also close via rack.after_reply
      (request.env['rack.after_reply'] ||= []) << -> { close_valkyrie_io(io) }
      self.response_body = Enumerator.new do |yielder|
        remaining = length
        while remaining.positive? && (chunk = io.read([CHUNK_SIZE, remaining].min))
          yielder << chunk
          remaining -= chunk.bytesize
        end
      ensure
        close_valkyrie_io(io)
      end
    end

    def close_valkyrie_io(io)
      io.close if io.respond_to?(:close) && !io.closed?
    end

    # send_range_valkyrie renders the response itself, so skip the
    # send_data call in Hyrax's send_file_contents_valkyrie
    def send_data(data, options = {})
      super unless performed?
    end

    def seek_valkyrie(io:, from:)
      return io.seek(from) if io.respond_to?(:seek)

      io.rewind
      skip = from
      while skip.positive? && (chunk = io.read([CHUNK_SIZE, skip].min))
        skip -= chunk.bytesize
      end
    end
  end
end

Hyrax::DownloadsController.prepend(Hyrax::ValkyrieDownloadsControllerBehaviorDecorator)
