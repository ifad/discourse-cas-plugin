# name: CAS
# about: Authenticate with discourse with CAS
# version: 0.1.0
# author: Erik Ordway

require "rubygems"
#addressable is set to require: false as the cas code will
# load the actual part that it needs at runtime.
gem 'addressable',  '2.3.4' , require: false
gem 'omniauth-cas', '1.0.4'

class CASAuthenticator < ::Auth::Authenticator

  #Required settings
  CAS_URL = 'https://YOUR.CAS.SERVER/cas'

  # Optional settings
  #attribute name in extra attributes for email address
  EMAIL = :UserPrincipalName
  #if the above is not set the plugin will set the
  #email address to username@CAS_EMAIL_DOMAIN if CAS_EMAIL_DOMAIN is set.
  #otherwise it will be set to username@
  CAS_EMAIL_DOMAIN = 'YOU.EMAIL.DOMAIN'

  #The attribute name in extra attributes for display name.
  #If the attribute can not be found the username will be used instead.
  NAME = :Name

  #Automatically approve the new user
  APPROVED = true

  def name
    'cas'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    #if the email address is set in the extra attributes and we know the accessor use it here
    email = auth_token[:extra][EMAIL] if (auth_token[:extra] && auth_token[:extra][EMAIL])
    #if we could not get the email address from the extra attributes try to set it base on the username
    email ||= unless CAS_EMAIL_DOMAIN.nil?
                "#{auth_token[:uid]}@#{CAS_EMAIL_DOMAIN}"
              else
                auth_token[:uid]
              end

    result.email = email
    result.email_valid = true

    result.username  = auth_token[:uid]

    result.name  = if auth_token[:extra] && auth_token[:extra][NAME]
                           auth_token[:extra]["Name"]
                         else
                           auth_token[:uid]
                         end

    # plugin specific data storage
    current_info = ::PluginStore.get("cas", "cas_uid_#{auth_token[:uid]}")
    result.user =
        if current_info
          User.where(id: current_info[:user_id]).first
        end
    result.user ||= User.where(email: email).first

    result
  end

  def after_create_account(user, auth)
    user.update_attribute(:approved, APPROVED)
    ::PluginStore.set("cas", "cas_uid_#{auth[:username]}", {user_id: user.id })
  end

  def register_middleware(omniauth)
    omniauth.provider :cas,
                      url: CAS_URL
  end
end


auth_provider :title => 'with CAS',
              :message => 'Log in via CAS (Make sure pop up blockers are not enabled).',
              :frame_width => 920,
              :frame_height => 800,
              :authenticator => CASAuthenticator.new


# We ship with zocial, it may have an icon you like http://zocial.smcllns.com/sample.html
#  in our current case we have an icon for vk
register_css <<CSS

.btn-social.cas {
  background: #70BA61;
}

.btn-social.cas:before {
  font-family: Ubuntu;
  content: "C";
}

CSS