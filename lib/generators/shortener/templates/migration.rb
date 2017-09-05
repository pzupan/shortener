class CreateShortenedUrlsTable < ActiveRecord::Migration[5.0]
  def change
    create_table :shortened_urls do |t|
      # we can link this to a user for interesting things
      t.integer :owner_id
      t.string :owner_type

      # the real url that we will redirect to
      t.text :url

      # the unique key
      t.string :unique_key

      # a category to help categorize shortened urls
      t.string :category

      # how many times the link has been clicked
      t.integer :use_count, default: 0

      # valid until date for expirable urls
      t.datetime :expires_at

      t.timestamps
    end

    # we will lookup the links in the db by key, urls and owners.
    # also make sure the unique keys are actually unique
    add_index :shortened_urls, :unique_key
    add_index :shortened_urls, :url
    add_index :shortened_urls, [:owner_id, :owner_type]
    add_index :shortened_urls, :category
  end
end
