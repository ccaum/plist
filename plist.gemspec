spec = Gem::Specification.new do |s|
  s.name = 'plist'
  s.version = '3.1.0'
  s.summary = "All-purpose Property List manipulation library"
  s.description = %{Plist is a library to manipulate Property List files, also known as plists. It can parse plist files into native Ruby data structures as well as generating new plist files from your Ruby objects.}
  s.files = Dir['lib/**/*.rb'] + Dir['test/**/*.rb']
  s.require_path = 'lib'
  s.autorequire = 'builder'
  s.has_rdoc = true
  s.extra_rdoc_files = Dir['[A-Z]*']
  s.rdoc_options << '--title' <<  'Plist -- All-purpose Property List manipulation library'
  s.author = "Ben Bleything"
  s.email = "ben@bleything.net"
  s.homepage = "https://github.com/bleything/plist"
end