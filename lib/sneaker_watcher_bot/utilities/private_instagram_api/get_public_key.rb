module PrivateInstagramApi
  class GetPublicKey
    def initialize(username, password)
      @username = username
      @password = password
    end

    def perform
      begin
        response = RestClient.post("#{base_url}/qe/sync/", request_body, request_headers)
        headers = response.headers.deep_symbolize_keys
        Normalizer::PublicKeyResponse.new(
          headers[:ig_set_password_encryption_key_id],
          headers[:ig_set_password_encryption_pub_key],
          device_id,
          android_id,
          phone_id
        )
      rescue => e
        log_object = {
          tags: self.class.name.underscore,
          message: e.message,
          backtrace: e.backtrace.take(5),
          instagram_username: @username
        }
        SneakerWatcherBot.logger.error(log_object)
        raise
      end
    end

    def base_url
      'https://b.i.instagram.com/api/v1'
    end

    def request_body
      experiments = %w[ig_android_device_detection_info_upload ig_android_gmail_oauth_in_reg
        ig_android_account_linking_upsell_universe ig_android_direct_main_tab_universe_v2
        ig_android_direct_add_direct_to_android_native_photo_share_sheet
        ig_growth_android_profile_pic_prefill_with_fb_pic_2
        ig_account_identity_logged_out_signals_global_holdout_universe
        ig_android_quickcapture_keep_screen_on ig_android_device_based_country_verification
        ig_android_login_identifier_fuzzy_match ig_android_reg_modularization_universe
        ig_android_video_render_codec_low_memory_gc
        ig_android_device_verification_separate_endpoint ig_android_suma_landing_page
        ig_android_smartlock_hints_universe ig_android_retry_create_account_universe
        ig_android_caption_typeahead_fix_on_o_universe
        ig_android_reg_nux_headers_cleanup_universe ig_android_nux_add_email_device
        ig_android_device_info_foreground_reporting ig_android_device_verification_fb_signup
        ig_android_passwordless_account_password_creation_universe
        ig_android_security_intent_switchoff ig_android_sim_info_upload
        ig_android_fb_account_linking_sampling_freq_universe]
      signed_body = {
        id: device_id,
        server_config_retrieval: '1',
        experiments: experiments.join(',')
      }
      {
        signed_body: "SIGNATURE.#{signed_body.to_json}"
      }
    end

    def request_headers
      {
        user_agent: Helper::CommonHelper::USER_AGENT,
        'X-DEVICE-ID': device_id,
        'X-IG-App-Locale': 'en_US',
        'X-IG-Device-Locale': 'en_US',
        'X-IG-Mapped-Locale': 'en_US',
        'X-IG-WWW-Claim': 0,
        'X-IG-Device-ID': device_id,
        'X-IG-Android-ID': android_id,
        'X-IG-App-ID': '567067343352427',
        'X-FB-HTTP-Engine': 'Liger',
        'X-FB-Client-IP': 'True',
        content_type: :json,
        accept: :json
      }
    end
  
    def device_id
      # generate uuid based on username password
      PrivateInstagramApi::Helper::CommonHelper.get_device_id(@username, @password)
    end

    def android_id
      @android_id ||= PrivateInstagramApi::Helper::CommonHelper.generate_android_id
    end

    def phone_id
      PrivateInstagramApi::Helper::CommonHelper.get_phone_id(device_id)
    end
  end
end
