require "test/test_helper"

class UseVanityController < ActionController::Base
  include Vanity::Rails

  def index
    render text: ab_test(:simple)
  end

  attr_accessor :current_user
end

# Pages accessible to everyone, e.g. sign in, community search.
class UseVanityTest < ActionController::TestCase
  tests UseVanityController

  def setup
    experiment :simple do
    end
    UseVanityController.class_eval do
      use_vanity :current_user
    end
  end

  def test_vanity_cookie_is_persistent
    get :index
    assert cookie = @response["Set-Cookie"].find { |c| c[/^vanity_id=/] }
    assert expires = cookie[/vanity_id=[a-f0-9]{32}; path=\/; expires=(.*)(;|$)/, 1]
    assert_in_delta Time.parse(expires), Time.now + 1.month, 1.minute
  end

  def test_vanity_cookie_default_id
    get :index
    assert_match cookies['vanity_id'], /^[a-f0-9]{32}$/
  end

  def test_vanity_cookie_retains_id
    @request.cookies['vanity_id'] = "from_last_time"
    get :index
    assert_equal "from_last_time", cookies['vanity_id']
  end

  def test_vanity_identity_set_from_cookie
    @request.cookies['vanity_id'] = "from_last_time"
    get :index
    assert_equal "from_last_time", @controller.send(:vanity_identity)
  end

  def test_vanity_identity_set_from_user
    @controller.current_user = mock("user", id: "user_id")
    get :index
    assert_equal "user_id", @controller.send(:vanity_identity)
  end

  def test_vanity_identity_with_no_user_model
    UseVanityController.class_eval do
      use_vanity nil
    end
    @controller.current_user = Object.new
    get :index
    assert_match cookies['vanity_id'], /^[a-f0-9]{32}$/
  end

  def test_use_vanity_requires_arguments
    assert_raise ArgumentError do
      UseVanityController.class_eval do
        use_vanity
      end
    end
  end

  def teardown
    UseVanityController.send(:filter_chain).clear
    nuke_playground
  end
end
