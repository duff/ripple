# Copyright 2010 Sean Cribbs, Sonian Inc., and Basho Technologies, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require File.expand_path("../spec_helper", __FILE__)
require 'ripple/session_store'

describe "Ripple::SessionStore" do
  include RSpec::Rails::RequestExampleGroup
  include Ripple::SessionStoreTest
  hooks[:before][:each].pop # Remove the router junk

  before :each do
    @app = build_app do |middleware|
      middleware.use Ripple::SessionStore, :key => '_session_id', :port => ($test_server ? 9000 : 8098)
      middleware.delete "ActionDispatch::ShowExceptions"
    end
    @app.routes.draw do
      match ':action', :to => ::Ripple::SessionStoreTest::TestController
    end
    ::Ripple::SessionStoreTest::TestController.send(:include, @app.routes.url_helpers)
  end

  it "should set and get a session value" do
    get '/set_session_value'
    response.should be_success
    cookies['_session_id'].should be

    get '/get_session_value'
    response.should be_success
    'foo: "bar"'.should == response.body
  end

  it "should get nothing from a new session" do
    get '/get_session_value'
    response.should be_success
    'foo: nil'.should == response.body
  end

  it "should get an empty session after reset" do
    get '/set_session_value'
    response.should be_success
    cookies['_session_id'].should be
    session_cookie = cookies.send(:hash_for)['_session_id']

    get '/call_reset_session'
    response.should be_success
    [].should_not == headers['Set-Cookie']

    cookies << session_cookie # replace our new session_id with our old, pre-reset session_id

    get '/get_session_value'
    response.should be_success
    'foo: nil'.should == response.body
  end

  it "should not create a session unless writing to it" do
    get '/get_session_value'
    response.should be_success
    'foo: nil'.should == response.body
    cookies['_session_id'].should be_nil
  end

  it "should set a value in the new session after reset" do
    get '/set_session_value'
    response.should be_success
    cookies['_session_id'].should be
    session_id = cookies['_session_id']

    get '/call_reset_session'
    response.should be_success
    [].should_not == headers['Set-Cookie']

    get '/get_session_value'
    response.should be_success
    'foo: nil'.should == response.body

    get '/get_session_id'
    response.should be_success
    session_id.should_not == response.body
  end
  
  it "should get the session id when the session exists" do
    get '/set_session_value'
    response.should be_success
    cookies['_session_id'].should be
    session_id = cookies['_session_id']

    get '/get_session_id'
    response.should be_success
    session_id.should == response.body
  end
  
  it "should deserialize an unloaded class" do
    with_autoload_path "session_autoload_test" do
      get '/set_serialized_session_value'
      response.should be_success
      cookies['_session_id'].should be
    end
    with_autoload_path "session_autoload_test" do
      get '/get_session_id'
      response.should be_success
    end
    with_autoload_path "session_autoload_test" do
      get '/get_session_value'
      response.should be_success
      'foo: #<SessionAutoloadTest::Foo bar:"baz">'.should == response.body
    end
  end
  
  it "should not send the session cookie again if the ID already exists" do
    get '/set_session_value'
    response.should be_success
    cookies['_session_id'].should be

    get '/get_session_value'
    response.should be_success
    headers['Set-Cookie'].should be_nil
  end
  
  it "should prevent session fixation" do
    get '/set_session_value'
    response.should be_success
    cookies['_session_id'].should be

    get '/get_session_value'
    response.should be_success
    headers['Set-Cookie'].should be_nil
  end
end

