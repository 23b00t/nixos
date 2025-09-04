{ pkgs, lib, config, inputs, ... }:

{
  # Keep useful parts from the default template
  env.GREET = "ruby-dev";
  
  packages = with pkgs; [
    # git
    # Ruby-specific packages
    ruby
    rubyPackages.solargraph
    rubyPackages.rubocop
    rubyPackages.byebug
    rubyPackages.json
    rubyPackages.nokogiri
    rubyPackages.prism
    rubyPackages.racc
    rubyPackages.rbs
    
    # Web development
    nodejs
    nodePackages.prettier
  ];

  env.OMP_CONFIG = ''''${OMP_CONFIG:-$HOME/.cache/oh-my-posh/themes/amro.omp.json}'';

  # Language support
  languages.ruby.enable = true;
  languages.ruby.version = "3.4.5";
  languages.javascript.enable = true;
  
  # Services
  # services.redis.enable = true;
  services.postgres.enable = true; 
  services.postgres.initialDatabases = [{ name = "test_db"; }];
  services.postgres.listen_addresses = "127.0.0.1";

  # Scripts
  scripts.hello.exec = ''
    echo "Hello from $GREET!"
    echo "Ruby version: $(ruby --version)"
  '';

  enterShell = ''
    zsh
    hello
    git --version
    echo "Ruby environment ready!"
  '';

  # Tests for this environment
  enterTest = ''
    echo "Running tests for Ruby environment"
    ruby --version | grep -q "ruby"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';
}
