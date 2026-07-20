# frozen_string_literal: true

# Knapsack Flipflop features; registered by the engine's flipflop initializer.
Flipflop.configure do
  feature :hls_streaming,
          default: false,
          description: 'Generate adaptive-bitrate HLS derivatives for A/V works, played by an HLS-compatible viewer.'
end
