Pod::Spec.new do |s|
  s.name         = "husl-objc"
  s.version      = "0.0.1"
  s.summary      = "HUSL is a human-friendly alternative to HSL."
  s.description  = <<-DESC
  CIELUV is a color space designed for perceptual uniformity based on human experiments. When accessed by polar coordinates, it becomes functionally similar to HSL with a single problem: its chroma component doesn't fit into a specific range.

  HUSL extends CIELUV with a new saturation component that allows you to span all the available chroma as a neat percentage.
                   DESC
  s.homepage     = "https://github.com/tallada/husl-objc"
  s.license      = {:type => "MIT", :file => "LICENSE.txt"}
  s.authors            = { "Alexei Boronine" => "alexei@boronine.com", "Roger Tallada" => "info@rogertallada.com" }
  s.ios.deployment_target = "6.0"
  s.osx.deployment_target = "10.7"
  s.source       = { :git => "https://github.com/tallada/husl-objc.git", :tag => "0.0.0" }
  s.source_files  = "husl-objc", "husl-objc/**/*.{h,m}"
  s.requires_arc = true
end
