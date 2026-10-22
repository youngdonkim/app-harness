# frozen_string_literal: true

# check_metadata.rb — 스토어 정보 폴더(fastlane/metadata/android/<로케일>/)를 플레이에 올리기 전에 점검합니다.
#
# 쓰는 법 (프로젝트 맨 위 폴더에서, 어느 브랜치에서나 — fastlane이 아니라 그냥 ruby로 돕니다):
#   ruby fastlane/check_metadata.rb                    # 글자 수·자리 표시·그림 크기
#   ruby fastlane/check_metadata.rb --version-code 12  # 위 + changelogs/12.txt가 있는지
#
# Fastfile도 올리기 전에 같은 점검을 부릅니다(MetadataCheck.run). 문제가 하나라도 있으면 올리지 않습니다.
# 루비 기본 라이브러리만 씁니다. 글자 수 한도는 플레이 콘솔 입력칸 기준이라 바뀔 수 있습니다 —
# 콘솔이 다른 한도를 보이면 아래 LIMITS를 고칩니다.

module MetadataCheck
  LIMITS = {
    "title.txt" => 30,
    "short_description.txt" => 80,
    "full_description.txt" => 4000
  }.freeze
  CHANGELOG_LIMIT = 500
  # 틀에 남은 자리 표시 — 「<앱 이름>」·「__PACKAGE_NAME__」 같은 꼴
  PLACEHOLDER = /<[^<>\n]{1,40}>|__[A-Z_]+__/.freeze

  module_function

  # 문제 목록(문자열 배열)을 돌려줍니다. 비어 있으면 통과입니다.
  def run(meta_dir, version_code: nil)
    problems = []
    unless Dir.exist?(meta_dir)
      return ["스토어 정보 폴더가 없습니다: #{meta_dir}"]
    end

    locales = Dir.children(meta_dir).select { |d| File.directory?(File.join(meta_dir, d)) }.sort
    problems << "로케일 폴더가 없습니다 (예: ko-KR)" if locales.empty?

    locales.each do |loc|
      dir = File.join(meta_dir, loc)
      LIMITS.each do |name, limit|
        path = File.join(dir, name)
        unless File.file?(path)
          problems << "#{loc}/#{name} 없음"
          next
        end
        text = File.read(path, encoding: "UTF-8").strip
        problems << "#{loc}/#{name} 비어 있음" if text.empty?
        problems << "#{loc}/#{name} #{text.length}자 — 한도 #{limit}자" if text.length > limit
        problems << "#{loc}/#{name} 틀의 자리 표시가 남음: #{text[PLACEHOLDER]}" if text.match?(PLACEHOLDER)
      end

      changelogs = File.join(dir, "changelogs")
      Dir.glob(File.join(changelogs, "*.txt")).each do |path|
        text = File.read(path, encoding: "UTF-8").strip
        rel = "#{loc}/changelogs/#{File.basename(path)}"
        problems << "#{rel} #{text.length}자 — 한도 #{CHANGELOG_LIMIT}자" if text.length > CHANGELOG_LIMIT
        problems << "#{rel} 틀의 자리 표시가 남음" if text.match?(PLACEHOLDER)
      end
      if version_code
        path = File.join(changelogs, "#{version_code}.txt")
        problems << "#{loc}/changelogs/#{version_code}.txt 없음 — 이번 빌드 번호의 변경 내역" unless File.file?(path)
      end

      problems.concat(check_images(File.join(dir, "images"), loc))
    end
    problems
  end

  def check_images(images, loc)
    problems = []
    return problems unless Dir.exist?(images)

    fixed = { "icon" => [512, 512], "featureGraphic" => [1024, 500] }
    fixed.each do |base, (w, h)|
      Dir.glob(File.join(images, "#{base}.{png,jpg,jpeg}")).each do |path|
        info = png_info(path)
        next unless info # JPEG는 크기를 읽지 않습니다 — 콘솔이 거르면 그때 고칩니다

        rel = "#{loc}/images/#{File.basename(path)}"
        problems << "#{rel} #{info[:w]}×#{info[:h]} — #{w}×#{h}여야 합니다" if [info[:w], info[:h]] != [w, h]
        problems << "#{rel} 투명 채널이 있음 — 그래픽 이미지는 투명 채널 없는 PNG여야 합니다" if base == "featureGraphic" && info[:alpha]
      end
    end

    shots = Dir.glob(File.join(images, "phoneScreenshots", "*.{png,jpg,jpeg}")).sort
    problems << "#{loc}/images/phoneScreenshots 스크린샷 #{shots.length}장 — 8장까지" if shots.length > 8
    problems << "#{loc}/images/phoneScreenshots 스크린샷 #{shots.length}장 — 2장 이상이어야 올릴 수 있습니다" if shots.length == 1
    shots.each do |path|
      info = png_info(path)
      next unless info

      rel = "#{loc}/images/phoneScreenshots/#{File.basename(path)}"
      short, long = [info[:w], info[:h]].minmax
      problems << "#{rel} #{info[:w]}×#{info[:h]} — 변마다 320~3840 화소" if short < 320 || long > 3840
      problems << "#{rel} 긴 변이 짧은 변의 2배를 넘음" if long > short * 2
      problems << "#{rel} 투명 채널이 있음 — 스크린샷은 투명 채널 없는 PNG(또는 JPEG)" if info[:alpha]
    end
    problems
  end

  # PNG 머리(IHDR)에서 가로·세로·투명 채널 여부를 읽습니다. PNG가 아니면 nil.
  def png_info(path)
    head = File.binread(path, 26)
    return nil unless head && head.bytesize >= 26 && head.byteslice(0, 8) == "\x89PNG\r\n\x1a\n".b

    w, h = head.byteslice(16, 8).unpack("NN")
    color_type = head.getbyte(25)
    # 4 = 회색+투명, 6 = 색+투명. 3(팔레트)은 tRNS 조각이 있으면 투명이지만 여기서는 보지 않습니다.
    { w: w, h: h, alpha: [4, 6].include?(color_type) }
  end
end

if $PROGRAM_NAME == __FILE__
  version_code = nil
  if (i = ARGV.index("--version-code"))
    version_code = ARGV[i + 1]
  end
  meta = File.expand_path("metadata/android", __dir__)
  problems = MetadataCheck.run(meta, version_code: version_code)
  if problems.empty?
    puts "스토어 정보 점검: 문제 없음"
  else
    puts "스토어 정보 점검: #{problems.length}건"
    problems.each { |p| puts "  - #{p}" }
    exit 1
  end
end
