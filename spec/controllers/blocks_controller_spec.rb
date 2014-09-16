require 'spec_helper'

describe BlocksController do

  let(:block_hash) { "000000008cd4b1bdaa1278e3f1708258f862da16858324e939dc650627cd2e27" }  
  let(:tx_hash) { "5872025cffc8894b116d5091bbc33986f23305d7b02c069f3eb7918a7e353e67" }

  describe :index do

    it "should render html" do
      get :index
      response.status.should == 200
      assigns(:blocks).count.should == 20
      assigns(:blocks).first[:hash].hth.should == block_hash
    end

  end
  
  describe :block do

    it "should render html" do
      get :block, id: block_hash
      response.status.should == 200
      assigns(:block).hash.should == block_hash
    end
      
    it "should render json" do
      get :block, id: block_hash, format: :json
      response.status.should == 200
      JSON.parse(response.body).should == STORE.get_block(block_hash).to_hash
    end

    it "should render bin" do
      get :block, id: block_hash, format: :bin
      response.status.should == 200
      response.body.should == STORE.get_block(block_hash).to_payload
    end

    it "should render hex" do
      get :block, id: block_hash, format: :hex
      response.status.should == 200
      response.body.should == STORE.get_block(block_hash).to_payload.hth
    end

  end

  describe :tx do

    it "should render html" do
      get :tx, id: tx_hash
      response.status.should == 200
      assigns(:tx).hash.should == tx_hash
    end

    it "should render json" do
      get :tx, id: tx_hash, format: :json
      response.status.should == 200
      JSON.parse(response.body).should == STORE.get_tx(tx_hash).to_hash(with_nid: true)
    end

    it "should render bin" do
      get :tx, id: tx_hash, format: :bin
      response.status.should == 200
      response.body.should == STORE.get_tx(tx_hash).to_payload
    end

    it "should render hex" do
      get :tx, id: tx_hash, format: :hex
      response.status.should == 200
      response.body.should == STORE.get_tx(tx_hash).to_payload.hth
    end

  end

  describe :address do

    let(:address) { "n2ESto3LRX8U7k7CxfLVac2eSaTvp98pni" }

    it "should render html" do
      get :address, id: address
      response.status.should == 200
      assigns(:address).should == address
      assigns(:hash160).should == Bitcoin.hash160_from_address(address)
      assigns(:addr_txouts).count.should == 20
    end

    it "should render json" do
      get :address, id: address, format: :json
      response.status.should == 200
      res = JSON.parse(response.body)
      res['address'].should == address
      res['hash160'].should == Bitcoin.hash160_from_address(address)
      res['tx_in_sz'].should == 20
      res['tx_out_sz'].should == 20
      res['btc_in'].should == 12431302
      res['btc_out'].should == 12431302
      res['balance'].should == 0
      res['tx_sz'].should == 38
      res['transactions'].size.should == 38
    end

  end

  describe :search do

    it "should search for block by hash" do
      get :search, search: block_hash
      response.should redirect_to(block_path(block_hash))
    end

    it "should search for tx by hash" do
      get :search, search: tx_hash
      response.should redirect_to(tx_path(tx_hash))
    end

    it "should search for tx by nhash" do
      tx = STORE.get_tx(tx_hash)
      get :search, search: tx.nhash
      response.should redirect_to(tx_path(tx_hash))
    end

    it "should search for address" do
      address = "mrf5iYUrgE2qePqpbjJ5bDCLcUWCRYAETT"
      get :search, search: address
      response.should redirect_to(address_path(address))
    end

  end

  describe :relay do

    include Bitcoin::Builder

    before do
      run_bitcoin_node
      @tx = build_tx do |t|
        t.input do |i|
          i.prev_out @fake_chain.store.get_head.tx.first.out.first.get_tx, 0
          i.signature_key @key
        end
        t.output do |o|
          o.value 12345
          o.to @key.addr
        end
      end
    end

    after do
      kill_bitcoin_node
    end

    let(:tx) { Bitcoin::P::Tx.new }

    it "should relay transaction to the bitcoin network" do
      post :relay_tx, tx: @tx.payload.hth, wait: 0
      assigns(:error).should == nil
      res = assigns(:result)
      res["success"].should == true
      res["hash"].should == @tx.hash
    end

    it "should fail when tx syntax is invalid" do
      @tx.instance_eval { @in = [] }
      post :relay_tx, tx: @tx.to_payload.hth, wait: 0
      assigns(:error).should == "Transaction syntax invalid."
      assigns(:result)["error"].should == "Transaction syntax invalid."
      assigns(:result)["details"].should == ["lists", [0, 1]]
    end

    it "should fail when tx context is invalid" do
      @tx.instance_eval { @in[0].prev_out = "\x00"*32 }
      post :relay_tx, tx: @tx.to_payload.hth, wait: 0
      assigns(:error).should == "Transaction context invalid."
      assigns(:result)["details"].should == ["prev_out", [["0000000000000000000000000000000000000000000000000000000000000000", 0]]]
    end

  end

end
