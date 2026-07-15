# frozen_string_literal: true

module ::GamifiedShop
  class Engine < ::Rails::Engine
    engine_name "gamified_shop"
    isolate_namespace GamifiedShop
    config.autoload_paths << File.join(config.root, "lib")
  end
end
