require "rails_helper"

RSpec.describe ChangeSetChange, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:change_set_change)).to be_valid
    end

    it "has valid trait factories" do
      %i[created modified deleted with_snapshots].each do |trait|
        expect(build(:change_set_change, trait)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:change_set) }
    it { is_expected.to belong_to(:requirement) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:change_type) }

    it "validates uniqueness of requirement within change set" do
      change = create(:change_set_change)
      duplicate = build(:change_set_change, change_set: change.change_set, requirement: change.requirement)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:requirement_id]).to include("already has a change in this change set")
    end

    it "allows same requirement in different change sets" do
      requirement = create(:requirement)
      create(:change_set_change, requirement: requirement)
      other = build(:change_set_change, requirement: requirement)
      expect(other).to be_valid
    end

    it "allows different requirements in same change set" do
      change_set = create(:change_set)
      create(:change_set_change, change_set: change_set)
      other = build(:change_set_change, change_set: change_set)
      expect(other).to be_valid
    end
  end

  describe "enum" do
    it { is_expected.to define_enum_for(:change_type).with_values(created: 0, modified: 1, deleted: 2) }
  end

  describe "defaults" do
    it "defaults to created change_type" do
      change = ChangeSetChange.new
      expect(change.change_type).to eq("created")
    end

    it "defaults before_snapshot to empty hash" do
      change = ChangeSetChange.new
      expect(change.before_snapshot).to eq({})
    end

    it "defaults after_snapshot to empty hash" do
      change = ChangeSetChange.new
      expect(change.after_snapshot).to eq({})
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      change = create(:change_set_change)
      expect(change.versions.count).to eq(1)
      expect(change.versions.last.event).to eq("create")
    end

    it "tracks updates" do
      change = create(:change_set_change)
      change.update!(change_type: :deleted)
      expect(change.versions.count).to eq(2)
      expect(change.versions.last.event).to eq("update")
    end
  end

  describe "#snapshot_before!" do
    it "captures requirement attributes into before_snapshot" do
      requirement = create(:requirement, title: "Safety Goal", body: "The system shall detect faults", requirement_type: :safety, asil_level: :asil_d)
      change = create(:change_set_change, requirement: requirement, before_snapshot: {})

      change.snapshot_before!

      expect(change.before_snapshot["title"]).to eq("Safety Goal")
      expect(change.before_snapshot["body"]).to eq("The system shall detect faults")
      expect(change.before_snapshot["requirement_type"]).to eq("safety")
      expect(change.before_snapshot["asil_level"]).to eq("asil_d")
      expect(change.before_snapshot["uid"]).to eq(requirement.uid)
      expect(change.before_snapshot["status"]).to eq("draft")
      expect(change.before_snapshot["priority"]).to eq("must_have")
      expect(change.before_snapshot["custom_attributes"]).to eq({})
    end

    it "captures module and section names" do
      requirement = create(:requirement)
      change = create(:change_set_change, requirement: requirement)

      change.snapshot_before!

      expect(change.before_snapshot["module_name"]).to eq(requirement.section.requirement_module.name)
      expect(change.before_snapshot["section_name"]).to eq(requirement.section.name)
    end

    it "persists the snapshot" do
      change = create(:change_set_change)
      change.snapshot_before!
      change.reload
      expect(change.before_snapshot).to include("title", "uid")
    end
  end

  describe "#snapshot_after!" do
    it "captures requirement attributes into after_snapshot" do
      requirement = create(:requirement, title: "Updated Title")
      change = create(:change_set_change, requirement: requirement, after_snapshot: {})

      change.snapshot_after!

      expect(change.after_snapshot["title"]).to eq("Updated Title")
      expect(change.after_snapshot["uid"]).to eq(requirement.uid)
    end

    it "persists the snapshot" do
      change = create(:change_set_change)
      change.snapshot_after!
      change.reload
      expect(change.after_snapshot).to include("title", "uid")
    end
  end

  describe "#snapshot!" do
    it "captures both snapshots from current state" do
      requirement = create(:requirement, title: "Current State")
      change = build(:change_set_change, requirement: requirement)

      change.snapshot!

      expect(change.before_snapshot["title"]).to eq("Current State")
      expect(change.after_snapshot["title"]).to eq("Current State")
    end
  end

  describe "#any_changes?" do
    it "returns true for created change type" do
      change = build(:change_set_change, :created)
      expect(change.any_changes?).to be true
    end

    it "returns true for deleted change type" do
      change = build(:change_set_change, :deleted)
      expect(change.any_changes?).to be true
    end

    it "returns true when snapshots differ" do
      change = build(:change_set_change, :with_snapshots)
      expect(change.any_changes?).to be true
    end

    it "returns false when snapshots are identical" do
      snapshot = { "title" => "Same", "body" => "Same", "requirement_type" => "functional",
                   "status" => "draft", "priority" => "must_have", "asil_level" => "qm",
                   "uid" => "PRJ-0001", "custom_attributes" => {} }
      change = build(:change_set_change, :modified, before_snapshot: snapshot, after_snapshot: snapshot)
      expect(change.any_changes?).to be false
    end

    it "returns false when before_snapshot is blank" do
      change = build(:change_set_change, :modified, before_snapshot: {}, after_snapshot: { "title" => "X" })
      expect(change.any_changes?).to be false
    end

    it "returns false when after_snapshot is blank" do
      change = build(:change_set_change, :modified, before_snapshot: { "title" => "X" }, after_snapshot: {})
      expect(change.any_changes?).to be false
    end
  end

  describe "#changed_fields" do
    it "returns changed fields with old and new values" do
      change = build(:change_set_change, :with_snapshots)
      fields = change.changed_fields

      expect(fields["title"]).to eq(["Original Title", "Updated Title"])
      expect(fields["body"]).to eq(["Original body", "Updated body"])
      expect(fields["status"]).to eq(["draft", "in_review"])
      expect(fields["asil_level"]).to eq(["qm", "asil_b"])
    end

    it "excludes unchanged fields" do
      change = build(:change_set_change, :with_snapshots)
      fields = change.changed_fields

      expect(fields).not_to have_key("requirement_type")
      expect(fields).not_to have_key("priority")
      expect(fields).not_to have_key("custom_attributes")
    end

    it "returns empty hash when before_snapshot is blank" do
      change = build(:change_set_change, before_snapshot: {}, after_snapshot: { "title" => "X" })
      expect(change.changed_fields).to eq({})
    end

    it "returns empty hash when after_snapshot is blank" do
      change = build(:change_set_change, before_snapshot: { "title" => "X" }, after_snapshot: {})
      expect(change.changed_fields).to eq({})
    end

    it "returns empty hash when snapshots are identical" do
      snapshot = { "title" => "Same", "body" => "Same" }
      change = build(:change_set_change, before_snapshot: snapshot, after_snapshot: snapshot)
      expect(change.changed_fields).to eq({})
    end
  end

  describe "#apply!" do
    it "applies after_snapshot attributes for modified change" do
      requirement = create(:requirement, title: "Old Title", status: :draft)
      change = create(:change_set_change, :modified, requirement: requirement,
        after_snapshot: { "title" => "New Title", "body" => "New body", "status" => "in_review",
                         "requirement_type" => "safety", "priority" => "must_have", "asil_level" => "asil_c",
                         "custom_attributes" => {}, "uid" => requirement.uid })

      change.apply!
      requirement.reload

      expect(requirement.title).to eq("New Title")
      expect(requirement.body).to eq("New body")
      expect(requirement.status).to eq("in_review")
      expect(requirement.requirement_type).to eq("safety")
      expect(requirement.asil_level).to eq("asil_c")
    end

    it "does not change UID on apply" do
      requirement = create(:requirement)
      original_uid = requirement.uid
      change = create(:change_set_change, :modified, requirement: requirement,
        after_snapshot: { "title" => "New", "uid" => "FAKE-9999" })

      change.apply!
      requirement.reload

      expect(requirement.uid).to eq(original_uid)
    end

    it "soft-deletes by setting status to obsolete for deleted change" do
      requirement = create(:requirement, status: :draft)
      change = create(:change_set_change, :deleted, requirement: requirement)

      change.apply!
      requirement.reload

      expect(requirement.status).to eq("obsolete")
    end

    it "applies after_snapshot for created change" do
      requirement = create(:requirement, title: "Placeholder")
      change = create(:change_set_change, :created, requirement: requirement,
        after_snapshot: { "title" => "Final Title", "body" => "Final body",
                         "requirement_type" => "safety", "status" => "draft",
                         "priority" => "should_have", "asil_level" => "asil_a",
                         "custom_attributes" => {}, "uid" => requirement.uid })

      change.apply!
      requirement.reload

      expect(requirement.title).to eq("Final Title")
      expect(requirement.requirement_type).to eq("safety")
      expect(requirement.priority).to eq("should_have")
    end

    it "does nothing for modified change with blank after_snapshot" do
      requirement = create(:requirement, title: "Original")
      change = create(:change_set_change, :modified, requirement: requirement, after_snapshot: {})

      change.apply!
      requirement.reload

      expect(requirement.title).to eq("Original")
    end
  end

  describe "SNAPSHOT_ATTRIBUTES" do
    it "contains the expected attributes" do
      expect(ChangeSetChange::SNAPSHOT_ATTRIBUTES).to contain_exactly(
        "uid", "title", "body", "requirement_type", "status", "priority", "asil_level", "custom_attributes"
      )
    end
  end

  describe "change_set association" do
    it "is accessible from change_set" do
      change_set = create(:change_set)
      change = create(:change_set_change, change_set: change_set)
      expect(change_set.change_set_changes).to include(change)
    end

    it "is destroyed when change_set is destroyed" do
      change_set = create(:change_set)
      create(:change_set_change, change_set: change_set)
      expect { change_set.destroy }.to change(ChangeSetChange, :count).by(-1)
    end
  end

  describe "requirement association" do
    it "is accessible" do
      requirement = create(:requirement)
      change = create(:change_set_change, requirement: requirement)
      expect(change.requirement).to eq(requirement)
    end
  end
end
