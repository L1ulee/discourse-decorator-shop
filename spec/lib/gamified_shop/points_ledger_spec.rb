# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::PointsLedger do
  fab!(:user)
  fab!(:admin)

  let(:grant) { GamifiedShop::PointLedgerEntry::ADMIN_GRANT }
  let(:deduct) { GamifiedShop::PointLedgerEntry::ADMIN_DEDUCT }
  let(:reward) { GamifiedShop::PointLedgerEntry::EVENT_REWARD }

  before { SiteSetting.gamified_shop_enabled = true }

  def balance
    GamifiedShop::PointAccount.balance_for(user.id)
  end

  def entries
    GamifiedShop::PointLedgerEntry.where(user_id: user.id).order(:id)
  end

  describe ".apply!" do
    it "creates the account, appends an entry and updates the cached balance" do
      entry =
        described_class.apply!(
          user_id: user.id,
          amount: 10,
          entry_type: grant,
          description: "welcome",
          created_by_id: admin.id,
        )

      expect(entry).to be_persisted
      expect(entry.user_id).to eq(user.id)
      expect(entry.amount).to eq(10)
      expect(entry.balance_after).to eq(10)
      expect(entry.entry_type).to eq(grant)
      expect(entry.description).to eq("welcome")
      expect(entry.created_by_id).to eq(admin.id)

      expect(GamifiedShop::PointAccount.where(user_id: user.id).count).to eq(1)
      expect(balance).to eq(10)
    end

    it "records the reference the entry was triggered by" do
      topic = Fabricate(:topic)

      entry =
        described_class.apply!(user_id: user.id, amount: 5, entry_type: reward, reference: topic)

      expect(entry.reference_type).to eq("Topic")
      expect(entry.reference_id).to eq(topic.id)
    end

    it "keeps balance_after correct across sequential applies" do
      e1 = described_class.apply!(user_id: user.id, amount: 10, entry_type: grant)
      e2 = described_class.apply!(user_id: user.id, amount: -3, entry_type: deduct)
      e3 = described_class.apply!(user_id: user.id, amount: 5, entry_type: grant)

      expect([e1, e2, e3].map(&:balance_after)).to eq([10, 7, 12])
      expect(balance).to eq(12)
      expect(entries.sum(:amount)).to eq(balance)
    end

    it "allows the balance to go negative" do
      entry = described_class.apply!(user_id: user.id, amount: -4, entry_type: deduct)

      expect(entry.amount).to eq(-4)
      expect(entry.balance_after).to eq(-4)
      expect(balance).to eq(-4)
    end

    it "creates no entry for a zero amount" do
      expect(described_class.apply!(user_id: user.id, amount: 0, entry_type: grant)).to be_nil

      expect(entries).to be_empty
      expect(balance).to eq(0)
    end

    it "does not update the balance when the entry cannot be created" do
      expect {
        described_class.apply!(user_id: user.id, amount: 5, entry_type: "bogus")
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(entries).to be_empty
      expect(balance).to eq(0)
    end

    it "rolls the entry back when the balance update fails" do
      allow_any_instance_of(GamifiedShop::PointAccount).to receive(:update_columns).and_raise(
        "boom",
      )

      expect { described_class.apply!(user_id: user.id, amount: 5, entry_type: grant) }.to(
        raise_error("boom"),
      )

      expect(entries).to be_empty
      expect(balance).to eq(0)
    end

    context "with a block" do
      it "uses the block result as the final amount, ignoring amount:" do
        entry =
          described_class.apply!(user_id: user.id, amount: 50, entry_type: reward) { |_account| 3 }

        expect(entry.amount).to eq(3)
        expect(entry.balance_after).to eq(3)
        expect(balance).to eq(3)
      end

      it "yields the locked account so the block can clamp against the balance" do
        described_class.apply!(user_id: user.id, amount: 8, entry_type: grant)

        entry =
          described_class.apply!(user_id: user.id, entry_type: reward) do |account|
            expect(account.user_id).to eq(user.id)
            [5, 10 - account.balance].min
          end

        expect(entry.amount).to eq(2)
        expect(balance).to eq(10)
      end

      it "aborts without an entry when the block returns nil" do
        result = described_class.apply!(user_id: user.id, entry_type: reward) { |_account| nil }

        expect(result).to be_nil
        expect(entries).to be_empty
        expect(balance).to eq(0)
      end

      it "aborts without an entry when the block returns zero" do
        result = described_class.apply!(user_id: user.id, entry_type: reward) { |_account| 0 }

        expect(result).to be_nil
        expect(entries).to be_empty
        expect(balance).to eq(0)
      end
    end
  end
end
