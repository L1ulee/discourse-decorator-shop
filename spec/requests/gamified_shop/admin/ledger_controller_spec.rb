# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Admin::LedgerController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:alice) { Fabricate(:user) }
  fab!(:bob) { Fabricate(:user) }

  before { SiteSetting.gamified_shop_enabled = true }

  def apply_entry!(target, amount, entry_type)
    GamifiedShop::PointsLedger.apply!(
      user_id: target.id,
      amount: amount,
      entry_type: entry_type,
      created_by_id: admin.id,
    )
  end

  context "when logged in as a normal user" do
    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/gamified-shop/ledger.json"

      expect(response.status).to eq(404)
    end
  end

  context "when logged in as a moderator" do
    before { sign_in(moderator) }

    it "returns 404 (the ledger is admin-only)" do
      get "/admin/plugins/gamified-shop/ledger.json"

      expect(response.status).to eq(404)
    end
  end

  context "when logged in as an admin" do
    before { sign_in(admin) }

    it "lists entries newest first" do
      reward = apply_entry!(alice, 10, "event_reward")
      grant = apply_entry!(bob, 5, "admin_grant")

      get "/admin/plugins/gamified-shop/ledger.json"

      expect(response.status).to eq(200)
      entries = response.parsed_body["entries"]
      expect(entries.map { |e| e["id"] }).to eq([grant.id, reward.id])
      expect(entries.last["amount"]).to eq(10)
      expect(entries.last["balance_after"]).to eq(10)
    end

    it "filters by entry_type" do
      reward = apply_entry!(alice, 10, "event_reward")
      apply_entry!(alice, -4, "purchase_spend")

      get "/admin/plugins/gamified-shop/ledger.json", params: { entry_type: "event_reward" }

      expect(response.status).to eq(200)
      entries = response.parsed_body["entries"]
      expect(entries.map { |e| e["id"] }).to eq([reward.id])
      expect(entries.first["entry_type"]).to eq("event_reward")
    end

    it "filters by username" do
      apply_entry!(alice, 10, "event_reward")
      grant = apply_entry!(bob, 5, "admin_grant")

      get "/admin/plugins/gamified-shop/ledger.json", params: { username: bob.username }

      expect(response.status).to eq(200)
      entries = response.parsed_body["entries"]
      expect(entries.map { |e| e["id"] }).to eq([grant.id])
      expect(entries.first["user_id"]).to eq(bob.id)
    end

    it "returns no entries for an unknown username" do
      apply_entry!(alice, 10, "event_reward")

      get "/admin/plugins/gamified-shop/ledger.json", params: { username: "no-such-user" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["entries"]).to eq([])
    end
  end
end
