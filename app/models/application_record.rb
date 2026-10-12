class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Translated enum value, e.g. Tournament.human_enum_name(:status, :finished) → "Завершён".
  def self.human_enum_name(enum, value)
    I18n.t("activerecord.enums.#{model_name.i18n_key}.#{enum}.#{value}")
  end
end
