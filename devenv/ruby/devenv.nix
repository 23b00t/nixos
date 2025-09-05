{ pkgs, lib, config, inputs, ... }:

{
  # Keep useful parts from the default template
  env.GREET = "ruby-dev";
  # env.OMP_CONFIG = ''''${OMP_CONFIG:-$HOME/.cache/oh-my-posh/themes/1_shell.omp.json}'';

  # Language support
  languages.ruby = {
    enable = true;
    version = "3.4.5";
    # gems = [
    #   pkgs.rubyPackages.bond
    #   pkgs.rubyPackages.hirb
    #   pkgs.rubyPackages.wirble
    # ];
  };
  languages.javascript.enable = true;
  
  # Services
  # services.redis.enable = true;
  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "dev_db"; }];
    listen_addresses = "127.0.0.1";
  };

  # Scripts
  scripts.hello.exec = ''
    echo "Hello from $GREET!"
    echo "Ruby version: $(ruby --version)"
  '';

  # scripts.irb_dev.exec = ''
  #   ruby -r bond -r hirb -r pry -e '
  #     Bond.start
  #     Hirb.enable
  #     Pry.start
  #   '
  # '';

  enterShell = ''
    hello
  '';

  # Tests for this environment
  enterTest = ''
    echo "Running tests for Ruby environment"
    ruby --version | grep -q "ruby"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';
}
