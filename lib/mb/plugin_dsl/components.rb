module MotherBrain
  module PluginDSL
    # @author Jamie Winsor <jamie@vialstudios.com>
    module Components
      include PluginDSL::Base
      
      # @return [HashWithIndifferentAccess]
      def components
        @components ||= HashWithIndifferentAccess.new
      end

      # @raise [PluginSyntaxError] if no block is given
      def component(&block)
        unless block_given?
          raise PluginSyntaxError, "Component definition missing a required block"
        end

        add_component Component.new(context, &block)
      end

      private

        # @param [Component] component
        def add_component(component)
          self.components[component.id] = component
        end

        # @param [Component] component
        def get_component(component)
          self.components.fetch(component.id, nil)
        end
    end
  end
end
