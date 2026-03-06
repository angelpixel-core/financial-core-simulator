require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do
    enable :login, :logout, :remember, :session_expiration

    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)
    convert_token_id_to_integer? { Account.columns_hash["id"].type == :integer }

    prefix "/admin"
    session_key_prefix "admin_"

    rails_controller { RodauthController }
    title_instance_variable :@page_title

    account_status_column :status
    account_password_hash_column :password_hash
    login_param "email"

    after_login { remember_login }
    extend_remember_deadline? true

    login_redirect "/admin/overview"
    logout_redirect { login_path }
  end
end
