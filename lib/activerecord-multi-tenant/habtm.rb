# frozen_string_literal: true

# This module extension is a monkey patch to the ActiveRecord::Associations::ClassMethods module.
# It overrides the has_and_belongs_to_many method to add the tenant_id to the join table if the
# tenant_enabled option is set to true.

module MultiTenant
  module HABTM
    def has_and_belongs_to_many(name, scope = nil, **opts, &extension)
      tenant_enabled    = opts.delete(:tenant_enabled)
      tenant_class_name = opts.delete(:tenant_class_name)
      tenant_column     = opts.delete(:tenant_column)

      super

      return unless tenant_enabled

      middle_reflection = _reflections[name.to_s].through_reflection
      join_model = middle_reflection.klass

      tenant_field_name = tenant_column.scan(/(\w+)_id/).dig(0, 0) || "tenant"

      join_model.class_eval do
        belongs_to tenant_field_name.to_sym, class_name: tenant_class_name
        before_create :tenant_set

        private

        # This method sets the tenant_id on the join table and executes before creation of the join table record.
        define_method :tenant_set do
          if tenant_enabled
            raise MultiTenant::MissingTenantError, "Tenant ID is not set" unless MultiTenant.current_tenant_id

            send("#{tenant_column}=", MultiTenant.current_tenant_id)
          end
        end
      end
    end
  end
end

ActiveRecord::Associations::ClassMethods.prepend(MultiTenant::HABTM)
