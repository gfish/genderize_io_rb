require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "http2"

describe "GenderizeIoRb" do
  it "can detect various names" do
    GenderizeIoRb.new do |gir|
      res = gir.info_for_name("kasper")
      res.name.should eq "kasper"
      res.gender.should eq "male"
      res.from_http_request?.should eq true

      res = gir.info_for_name("christina")
      res.name.should eq "christina"
      res.gender.should eq "female"
      res.from_http_request?.should eq true
    end
  end

  it "should accept a block to destroy automatically" do
    gir = GenderizeIoRb.new{ |gir| }
    gir.destroyed?.should eq true
  end

  it "can use a db cache" do
    require "baza"
    require "tmpdir"
    require "sqlite3"

    Baza::Db.new(type: "sqlite3", path: "#{Dir.tmpdir}/genderize_io_rb_spec_#{Time.now.to_f.to_s}.sqlite3", debug: false) do |db|
      GenderizeIoRb.new(cache_db: db) do |gir|
        res = gir.info_for_name("kasper")
        res.name.should eq "kasper"
        res.from_http_request?.should eq true

        res = gir.cache_db.select(:genderize_io_rb_cache, "name" => "kasper")

        count = 0
        res.each do |data|
          data[:name].should eq "kasper"
          count += 1
        end

        count.should > 0

        expect {
          gir.cache_db.insert(:genderize_io_rb_cache, name: "kasper")
        }.to raise_error

        res = gir.info_for_name("kasper")
        res.name.should eq "kasper"
        res.from_cache_db?.should eq true
      end
    end
  end

  it "should raise errors when a name is not found" do
    GenderizeIoRb.new do |gir|
      expect {
        gir.info_for_name("ksldfjslkjfweuir")
      }.to raise_error(GenderizeIoRb::Errors::NameNotFound)
    end
  end

  it "can do a multi-name request to speed it up with partly cache from a database" do
    require "baza"
    require "tmpdir"
    require "sqlite3"

    path = "#{Dir.tmpdir}/genderize_io_rb_spec_#{Time.now.to_f.to_s}.sqlite3"
    File.unlink(path) if File.exists?(path)

    Baza::Db.new(type: "sqlite3", path: path, debug: false) do |db|
      GenderizeIoRb.new(cache_db: db, debug: false) do |gir|
        results = gir.info_for_names(["kasper", "christina", "asdjkvujksuhdv"])

        results[0].name.should eq "kasper"
        results[0].gender.should eq "male"
        results[0].from_http_request?.should eq true

        results[1].name.should eq "christina"
        results[1].gender.should eq "female"
        results[1].from_http_request?.should eq true

        results[2].is_a?(::GenderizeIoRb::Errors::NameNotFound).should eq true
        results[2].name.should eq "asdjkvujksuhdv"


        results = gir.info_for_names(["kasper", "charlotte", "bsdjkvujksuhdv"])

        results[0].name.should eq "kasper"
        results[0].gender.should eq "male"
        results[0].from_cache_db?.should eq true

        results[1].name.should eq "charlotte"
        results[1].gender.should eq "female"
        results[1].from_http_request?.should eq true

        results[2].is_a?(::GenderizeIoRb::Errors::NameNotFound).should eq true
        results[2].name.should eq "bsdjkvujksuhdv"
      end
    end
  end

  it "should automatically chomp up a lot of names to avoid errors" do
    names = JSON.parse(File.read("#{File.dirname(__FILE__)}/shitload_of_names.json"))
    names = names.map{ |name| name.slice(1, name.length) }

    GenderizeIoRb.new do |gir|
      # Check returning of array.
      results = gir.info_for_names(names)
      results.length.should eq names.length

      # Check yielding works so it is possible to save memory.
      count = 0
      gir.info_for_names(names) do |result|
        count += 1
      end

      count.should eq names.length
    end
  end

  it "should add apikey when argument has api_key" do
    names = JSON.parse(File.read("#{File.dirname(__FILE__)}/shitload_of_names.json"))
    names = names.map{ |name| name.slice(1, name.length) }.first(25).unshift

    GenderizeIoRb.new(api_key: 1234) do |gir|
      gir.__send__(:generate_urls_from_names, names).each do |url|
        url.should include("?apikey=1234&")
      end
    end

    GenderizeIoRb.new do |gir|
      gir.__send__(:generate_urls_from_names, names).each do |url|
        url.should include("?name[0]=")
      end
    end
  end

  it "should raise errors when json result include error" do
    Http2.stub(:get) { '{"error": "Some error from json"}' }
    GenderizeIoRb.new do |gir|
      expect {
        gir.info_for_name("kasper")
      }.to raise_error(GenderizeIoRb::Errors::ResultError)
    end
  end

  describe "#load_dict" do
    it "should load gender dictionary as JSON" do
      gir = GenderizeIoRb.new
      names_json = gir.load_dict
      names_json.class.should eq Hash
      names_json.length.should > 7000
      names_json.key?('Facebook').should be_true
    end
  end

  describe "#gender_in_dict" do
    it "should load gender dictionary as JSON" do
      gir = GenderizeIoRb.new
      gir.gender_in_dict('kasper').should eq 'male'
      gir.gender_in_dict('Kasper  ').should eq 'male'
      gir.gender_in_dict('balabala  ').should eq nil
      gir.gender_in_dict('facebook').should eq nil
    end
  end
end
