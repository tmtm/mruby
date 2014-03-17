MRuby::Gem::Specification.new('mruby-bin-mirb') do |spec|
  spec.license = 'MIT'
  spec.author  = 'mruby developers'
  spec.summary = 'mirb command'

  spec.linker.libraries << 'readline' if spec.cc.defines.include? "ENABLE_READLINE"

  spec.bins = %w(mirb)

  if MRuby::Build.current && MRuby::Build.current.name == "host"
    if %w(/usr/include /usr/local/include /usr/pkg/include).any?{|path| File.exist?(File.join path, 'readline') }
      spec.cc.flags << '-DENABLE_READLINE'
      if %w(/usr/lib /usr/local/lib /usr/pkg/lib).any?{|path| File.exist?(File.join path, 'libedit.a') }
        spec.linker.libraries << 'edit'
        spec.linker.libraries << 'termcap'
      else
        spec.linker.libraries << 'readline'
      end
    end
  end
end
