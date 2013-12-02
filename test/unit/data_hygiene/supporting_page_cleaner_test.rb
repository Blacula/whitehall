require 'test_helper'
require 'data_hygiene/supporting_page_cleaner'

class SupportingPageCleanerTest < ActiveSupport::TestCase

  test "destroys duplicate superseded supporting pages and their attachments" do
    first_edition     = create_migrated_supporting_page(:superseded, body: 'original body', title: 'original title')
    dup1_edition      = duplicate_migrated_supportig_page(first_edition)
    second_edition    = duplicate_migrated_supportig_page(dup1_edition, state: :superseded, body: 'Body was updated')
    create(:file_attachment, attachable: second_edition)

    dup2_edition      = duplicate_migrated_supportig_page(second_edition)
    dup3_edition      = duplicate_migrated_supportig_page(dup2_edition, state: :superseded, title: 'Title updated')
    published_edition = duplicate_migrated_supportig_page(dup3_edition, state: :published)
    draft_edition     = published_edition.create_draft(create(:policy_writer))

    first_attachment  = second_edition.reload.attachments.first
    dup2_attachment   = dup2_edition.reload.attachments.first
    dup3_attachment   = dup3_edition.reload.attachments.first
    pub_attachment    = published_edition.reload.attachments.first
    draft_attachment  = draft_edition.reload.attachments.first


    cleaner = SupportingPageCleaner.new(published_edition.document)
    cleaner.delete_duplicate_superseded_editions!

    refute SupportingPage.exists? dup1_edition
    refute SupportingPage.exists? dup2_edition
    refute SupportingPage.exists? dup3_edition

    assert SupportingPage.exists? first_edition
    assert SupportingPage.exists? second_edition
    assert SupportingPage.exists? published_edition
    assert SupportingPage.exists? draft_edition

    refute Attachment.exists? dup2_attachment
    refute Attachment.exists? dup3_attachment

    assert Attachment.exists? first_attachment
    assert Attachment.exists? pub_attachment
    assert Attachment.exists? draft_attachment
  end

  test "#repair_version_history fixes the versioning and change history for migrated supporting pages, ignoring non-migrated ones" do
    first_edition     = create_migrated_supporting_page(:superseded, change_note: "Policy's change note")
    second_edition    = duplicate_migrated_supportig_page(first_edition)
    third_edition     = duplicate_migrated_supportig_page(second_edition, state: :published)
    new_edition       = third_edition.create_draft(create(:policy_writer))
    new_edition.change_note = "Updated by an editor"
    new_edition.minor_change = false
    force_publish(new_edition)

    cleaner = SupportingPageCleaner.new(first_edition.document)
    cleaner.repair_version_history!

    # All change notes should be cleared as they will have been copied from the parent policy, so already appear in the history
    assert_nil first_edition.reload.change_note
    assert_nil second_edition.reload.change_note
    assert_nil third_edition.reload.change_note

    # All versions are designated version 1.0 as guessing what's a major and what's a minor change is too difficult.
    assert_equal '1.0', first_edition.published_version
    assert_equal '1.0', second_edition.published_version
    assert_equal '1.0', third_edition.published_version

    # All but the first edition should be minor changes; see above.
    refute first_edition.minor_change?
    assert second_edition.minor_change?
    assert third_edition.minor_change?

    # Version numbers for editor-created editions are updated, but nothing else
    refute new_edition.reload.minor_change?
    assert_equal 'Updated by an editor', new_edition.change_note
    assert_equal '2.0', new_edition.published_version
  end

  test "#repair_version_history corrects the timestamps of migrated and subsequent editions" do
    first_edition = create_migrated_supporting_page(:superseded, change_note: "Policy's change note", first_published_at: 1.week.ago)
    first_policy  = OldSupportingPage.find(first_edition.editioned_supporting_page_mapping.old_supporting_page_id).edition
    first_policy.update_column(:first_published_at, 2.weeks.ago)
    first_policy.update_column(:public_timestamp, 2.weeks.ago)

    second_edition = duplicate_migrated_supportig_page(first_edition)
    second_policy  = OldSupportingPage.find(second_edition.editioned_supporting_page_mapping.old_supporting_page_id).edition
    second_policy.update_column(:first_published_at, 1.weeks.ago)
    second_policy.update_column(:public_timestamp, 1.weeks.ago)

    major_change = create(:supporting_page, :published, document: first_edition.document, related_policies: first_edition.related_policies,
                          first_published_at: first_edition.first_published_at, major_change_published_at: 2.days.ago)

    minor_change = major_change.create_draft(create(:policy_writer))
    minor_change.minor_change = true
    force_publish(minor_change)

    cleaner = SupportingPageCleaner.new(first_edition.document)
    cleaner.repair_version_history!

    # migrated editions inherit their timestamps from their oldest parent policy
    assert_equal 2.weeks.ago, first_edition.reload.first_published_at
    assert_equal 2.weeks.ago, first_edition.public_timestamp

    # subsequent editions re-calculate their public timestamps
    assert_equal 2.weeks.ago, major_change.reload.first_published_at
    assert_equal 2.days.ago,  major_change.public_timestamp
    assert_equal 2.weeks.ago, minor_change.reload.first_published_at
    assert_equal 2.days.ago,  minor_change.public_timestamp
  end

private

  def create_migrated_supporting_page(state, overrides={})
    attributes = { published_minor_version: nil, published_major_version: nil, first_published_at: Time.zone.now, public_timestamp: Time.zone.now }.merge(overrides)

    create(:supporting_page, state, attributes).tap do |edition|
      old_supporting_page = OldSupportingPage.create!(edition_id: create(:policy, :published).id)
      EditionedSupportingPageMapping.create!(new_supporting_page_id: edition.id, old_supporting_page_id: old_supporting_page.id)
    end
  end

  def duplicate_migrated_supportig_page(original, options={})
    body        ||= options.fetch(:body, original.body)
    title       ||= options.fetch(:title, original.title)
    state       ||= options.fetch(:state, original.current_state)
    change_note ||= options.fetch(:change_note, original.change_note)

    attributes = { body: body, title: title, change_note: change_note, document: original.document, related_policies: original.related_policies }

    create_migrated_supporting_page(state, attributes).tap do |edition|
      original.attachments(true).each { |attachment| edition.attachments << attachment.class.new(attachment.attributes) }
    end
  end
end
