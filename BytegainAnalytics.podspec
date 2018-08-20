Pod::Spec.new do |s|
  s.name             = "BytegainAnalytics"
  s.version          = "4.0.0"
  s.summary          = "Win the heart of every user."

  s.description      = <<-DESC
                       BytegainAnalytics for iOS uses AI to predict what
                       each user needs in real-time to help you serve
                       them in the best possible way.
                       DESC

  s.homepage         = "http://bytegain.com/"
  s.license          =  { :type => 'MIT' }
  s.author           = { "Bytegain" => "cocoapods@bytegain.com" }
  s.source           = { :git => "https://github.com/ByteGain/bg-analytics-ios.git", :tag => s.version.to_s }
  s.social_media_url = 'https://mobile.twitter.com/bytegain'

  s.ios.deployment_target = '7.0'
  s.tvos.deployment_target = '9.0'

  s.framework = 'Security'

  s.source_files = [
    'BytegainAnalytics/Classes/**/*',
    'BytegainAnalytics/Vendor/**/*'
  ]
end
