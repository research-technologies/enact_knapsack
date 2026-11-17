# frozen_string_literal: true

module HykuKnapsack
  # Stands in for Hyrax::Pid::DataCite::Client so the "Mint DOI" admin
  # button can be demoed end-to-end in this knapsack without real DataCite
  # credentials or a network call. Duck-types the same #call(method:, path:,
  # body:) interface Hyrax::Pid::DataCite::Minter expects, and keeps an
  # in-memory record of minted DOIs per-process so a mint -> publish ->
  # find round trip behaves consistently within one server run.
  #
  # Swap this out (via config/initializers/hyrax_pid.rb) for a real client,
  # or nil, once real DataCite credentials are available.
  class FakeDataCiteClient
    def initialize
      @dois = {}
    end

    # @param method [Symbol] :get, :post, or :put
    # @param path [String] e.g. "/dois" or "/dois/10.1234/abcde"
    # @param body [Hash, nil] a DataCite JSON:API request body
    # @return [Hash] a DataCite JSON:API-shaped response body
    def call(method:, path:, body: nil)
      case method
      when :post then create(body)
      when :put then update(path, body)
      when :get then find(path)
      end
    end

    private

    def create(body)
      attributes = body.dig(:data, :attributes) || {}
      doi = "#{attributes[:prefix]}/fake.#{SecureRandom.hex(4)}"
      store(doi, attributes.merge(doi: doi, state: "draft"))
    end

    def update(path, body)
      doi = doi_from(path)
      attributes = body.dig(:data, :attributes) || {}
      state = attributes[:event] == "publish" ? "findable" : (@dois.dig(doi, "state") || "draft")
      store(doi, (@dois[doi] || {}).merge(attributes.except(:event)).merge(doi: doi, state: state))
    end

    def find(path)
      doi = doi_from(path)
      record = @dois.fetch(doi) { {"doi" => doi, "state" => "findable"} }
      {"data" => {"id" => doi, "type" => "dois", "attributes" => record}}
    end

    def store(doi, attributes)
      @dois[doi] = attributes.transform_keys(&:to_s)
      {"data" => {"id" => doi, "type" => "dois", "attributes" => @dois[doi]}}
    end

    def doi_from(path)
      path.to_s.delete_prefix("/dois/")
    end
  end
end
