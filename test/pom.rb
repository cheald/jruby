version = File.read( File.join( basedir, '..', 'VERSION' ) ).strip
project 'JRuby Integration Tests' do

  model_version '4.0.0' 

  inherit 'org.jruby:jruby-parent', version
  id 'org.jruby:jruby-tests'

  repository( 'http://rubygems-proxy.torquebox.org/releases',
              :id => 'rubygems-releases' )
  repository( 'http://rubygems-proxy.torquebox.org/prereleases',
              :id => 'rubygems-prereleases' ) do
    releases 'false'
    snapshots 'true'
  end

  plugin_repository( 'https://oss.sonatype.org/content/repositories/snapshots/',
                     :id => 'sonatype' ) do
    releases 'false'
    snapshots 'true'
  end
  plugin_repository( 'http://rubygems-proxy.torquebox.org/releases',
                     :id => 'rubygems-releases' )

  properties( 'tesla.dump.pom' => 'pom.xml',
              'tesla.dump.readonly' => true,
              'jruby.home' => '${basedir}/..',
              'gem.home' => '${jruby.home}/lib/ruby/gems/shared' )

  scope :test do
    jar 'junit:junit:4.11'
    jar 'commons-logging:commons-logging:1.1.3'
    jar 'org.livetribe:livetribe-jsr223:2.0.7'
    jar 'org.jruby:jruby-core:${version}'
  end
  scope :provided do
    jar 'org.apache.ant:ant:${ant.version}'
    jar 'bsf:bsf:2.4.0'
  end
  jar( 'org.jruby:requireTest:1.0',
       :scope => 'system',
       :systemPath => '${project.basedir}/jruby/requireTest-1.0.jar' )
  gem 'rubygems:rspec:${rspec.version}'
  gem 'rubygems:minitest:${minitest.version}'
  gem 'rubygems:minitest-excludes:${minitest-excludes.version}'

  overrides do
    plugin( 'org.eclipse.m2e:lifecycle-mapping:1.0.0',
            'lifecycleMappingMetadata' => {
              'pluginExecutions' => [ { 'pluginExecutionFilter' => {
                                          'groupId' =>  'de.saumya.mojo',
                                          'artifactId' =>  'gem-maven-plugin',
                                          'versionRange' =>  '[1.0.0-rc3,)',
                                          'goals' => [ 'initialize' ]
                                        },
                                        'action' => {
                                          'ignore' =>  ''
                                        } } ]
            } )
  end

  jruby_plugin :gem, '${jruby.plugins.version}' do
    options = { :phase => 'initialize',
      'gemPath' => '${gem.home}',
      'gemHome' => '${gem.home}',
      'binDirectory' => '${jruby.home}/bin',
      'includeRubygemsInTestResources' => 'false' }

    if version =~ /-SNAPSHOT/
      options[ 'jrubyVersion' ] = '1.7.12'
    else
      options[ 'libDirectory' ] = '${jruby.home}/lib'
      options[ 'jrubyJvmArgs' ] = '-Djruby.home=${jruby.home}'
    end
    execute_goals( 'initialize', options )
  end

  plugin( :compiler,
          'encoding' =>  'utf-8',
          'debug' =>  'true',
          'verbose' =>  'true',
          'fork' =>  'true',
          'showWarnings' =>  'true',
          'showDeprecation' =>  'true',
          'source' =>  '${base.java.version}',
          'target' =>  '${base.java.version}' )
  plugin :dependency do
    execute_goals( 'copy',
                   :id => 'copy jars for testing',
                   :phase => 'process-classes',
                   'artifactItems' => [ { 'groupId' =>  'junit',
                                          'artifactId' =>  'junit',
                                          'version' =>  '4.11',
                                          'type' =>  'jar',
                                          'overWrite' =>  'false',
                                          'outputDirectory' =>  'target',
                                          'destFileName' =>  'junit.jar' },
                                        { 'groupId' =>  'com.googlecode.jarjar',
                                          'artifactId' =>  'jarjar',
                                          'version' =>  '1.1',
                                          'type' =>  'jar',
                                          'overWrite' =>  'false',
                                          'outputDirectory' =>  'target',
                                          'destFileName' =>  'jarjar.jar' },
                                        { 'groupId' =>  'bsf',
                                          'artifactId' =>  'bsf',
                                          'version' =>  '2.4.0',
                                          'type' =>  'jar',
                                          'overWrite' =>  'false',
                                          'outputDirectory' =>  'target',
                                          'destFileName' =>  'bsf.jar' } ] )
  end

  plugin( :deploy,
          'skip' =>  'true' )
  plugin( :site,
          'skip' =>  'true',
          'skipDeploy' =>  'true' )

  build do
    default_goal 'test'
    test_source_directory '.'
  end

  profile 'bootstrap' do
    unless version =~ /-SNAPSHOT/
      gem 'rubygems:jruby-launcher:${jruby-launcher.version}'
    end
  end

  profile 'rake' do

    plugin :antrun do
      execute_goals( 'run',
                     :id => 'rake',
                     :phase => 'test',
                     :configuration => [ xml( '<target><exec dir="${jruby.home}" executable="${jruby.home}/bin/jruby" failonerror="true"><arg value="-S"/><arg value="rake"/><arg value="${task}"/></exec></target>' ) ] )
    end

  end

  profile 'jars-test' do

    jar 'org.jruby:jruby-complete', '${project.version}', :scope => :provided

    rake = Dir[File.join(basedir, "../lib/ruby/gems/shared/gems/rake-*/lib/rake/rake_test_loader.rb")].first
    files = ""
    File.open(File.join(basedir, 'jruby.index')) do |f|
      f.each_line.each do |line|
        filename = "test/#{line.chomp}.rb"
        next unless File.exist? filename
        files << "<arg value='#{filename}'/>"
      end
    end

    plugin :antrun do
      execute_goals( 'run',
                     :id => 'jars',
                     :phase => 'test',
                     :configuration => [ xml( "<target><exec dir='${jruby.home}' executable='java' failonerror='true'><arg value='-cp'/><arg value='core/target/test-classes:test/target/test-classes:maven/jruby-complete/target/jruby-complete-${project.version}.jar'/><arg value='org.jruby.Main'/><arg value='-I.'/><arg value='#{rake}'/>#{files}<arg value='-v'/></exec></target>" ) ] )
    end

  end

  profile 'truffle-specs-language' do

    plugin :antrun do
      execute_goals( 'run',
                     :id => 'rake',
                     :phase => 'test',
                     :configuration => [ xml(
                      '<target>' + 
                        '<exec dir="${jruby.home}" executable="${jruby.home}/bin/jruby" failonerror="true">' +
                          '<arg value="-X+T" />' +
                          '<arg value="-Xparser.warn.useless_use_of=false" />' +
                          '<arg value="-Xparser.warn.not_reached=false" />' +
                          '<arg value="-Xparser.warn.grouped_expressions=false" />' +
                          '<arg value="-Xparser.warn.shadowing_local=false" />' +
                          '<arg value="-Xparser.warn.regex_condition=false" />' +
                          '<arg value="-Xparser.warn.argument_prefix=false" />' +
                          '<arg value="-Xcompliance.strict=true" />' +
                          '<arg value="-J-ea" />' +
                          '<arg value="spec/mspec/bin/mspec" />' +
                          '<arg value="run" />' +
                          '<arg value="-t" />' +
                          # Workaround for RubySpec #292
                          '<arg value="spec/truffle/spec-wrapper" />' +
                          #'<arg value="bin/jruby" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-X+T" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.useless_use_of=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.not_reached=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.grouped_expressions=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.shadowing_local=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.regex_condition=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.argument_prefix=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xcompliance.strict=true" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-J-ea" />' +
                          '<arg value="--config" />' +
                          '<arg value="spec/truffle/truffle.mspec" />' +
                          '<arg value="--excl-tag" />' +
                          '<arg value="fails" />' +
                          '<arg value=":language" />' +
                        '</exec>' +
                      '</target>' ) ] )
    end

  end

  profile 'truffle-specs-core' do

    plugin :antrun do
      execute_goals( 'run',
                     :id => 'rake',
                     :phase => 'test',
                     :configuration => [ xml(
                      '<target>' + 
                        '<exec dir="${jruby.home}" executable="${jruby.home}/bin/jruby" failonerror="true">' +
                          '<arg value="-X+T" />' +
                          '<arg value="-Xparser.warn.useless_use_of=false" />' +
                          '<arg value="-Xparser.warn.not_reached=false" />' +
                          '<arg value="-Xparser.warn.grouped_expressions=false" />' +
                          '<arg value="-Xparser.warn.shadowing_local=false" />' +
                          '<arg value="-Xparser.warn.regex_condition=false" />' +
                          '<arg value="-Xparser.warn.argument_prefix=false" />' +
                          '<arg value="-Xcompliance.strict=true" />' +
                          '<arg value="-J-ea" />' +
                          '<arg value="spec/mspec/bin/mspec" />' +
                          '<arg value="run" />' +
                          '<arg value="-t" />' +
                          # Workaround for RubySpec #292
                          '<arg value="spec/truffle/spec-wrapper" />' +
                          #'<arg value="bin/jruby" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-X+T" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.useless_use_of=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.not_reached=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.grouped_expressions=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.shadowing_local=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.regex_condition=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xparser.warn.argument_prefix=false" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-Xcompliance.strict=true" />' +
                          #'<arg value="-T" />' +
                          #'<arg value="-J-ea" />' +
                          '<arg value="--config" />' +
                          '<arg value="spec/truffle/truffle.mspec" />' +
                          '<arg value="--excl-tag" />' +
                          '<arg value="fails" />' +
                          '<arg value=":core" />' +
                        '</exec>' +
                      '</target>' ) ] )
    end

  end

  profile 'truffle-test-pe' do

    plugin :antrun do
      execute_goals( 'run',
                     :id => 'rake',
                     :phase => 'test',
                     :configuration => [ xml(
                      '<target>' + 
                        '<exec dir="${jruby.home}" executable="${jruby.home}/bin/jruby" failonerror="true">' +
                          '<arg value="-J-server" />' +
                          '<arg value="-J-G:-TruffleBackgroundCompilation" />' +
                          '<arg value="-J-G:+TruffleCompilationExceptionsAreFatal" />' +
                          '<arg value="-X+T" />' +
                          '<arg value="-Xtruffle.debug.enable_assert_constant=true" />' +
                          '<arg value="test/truffle/pe/pe.rb" />' +
                        '</exec>' +
                      '</target>' ) ] )
    end

  end

end
