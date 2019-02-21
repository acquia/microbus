# rubocop:disable LineLength
Then(/^(?:a|the) file(?: named)? "([^"]*)" should (not )?contain the SHA-256 digest for "([^"]*)"/) do |digest_file, negated, file|
  digest = Digest::SHA256.file(expand_path(file)).hexdigest
  if negated
    expect(digest_file).not_to \
      have_file_content file_content_including(digest)
  else
    expect(digest_file).to have_file_content file_content_including(digest)
  end
end
# rubocop:enable LineLenth
