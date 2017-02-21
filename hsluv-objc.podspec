Pod::Spec.new do |s|
  s.name         = "hsluv-objc"
  s.version      = "2.0.0"
  s.summary      = "HSLuv is a human-friendly alternative to HSL."
  s.description  = <<-DESC
  CIELUV is a color space designed for perceptual uniformity based on human experiments. When accessed by polar coordinates, it becomes functionally similar to HSL with a single problem: its chroma component doesn't fit into a specific range.

  HSLuv extends CIELUV with a new saturation component that allows you to span all the available chroma as a neat percentage.
                   DESC
  s.homepage     = "https://github.com/hsluv/hsluv-objc"
  s.license      = {:type => "MIT", :file => "LICENSE.txt"}
  s.authors      = { "Alexei Boronine" => "alexei@boronine.com", "Roger Tallada" => "info@rogertallada.com" }
  s.ios.deployment_target = "6.0"
  s.osx.deployment_target = "10.7"
  s.source       = { :git => "https://github.com/hsluv/hsluv-objc.git", :tag => "2.0.0" }
  s.source_files  = "hsluv-objc", "hsluv-objc/**/*.{h,m}"
  s.requires_arc = true
end
