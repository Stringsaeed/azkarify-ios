enum Celebration {
  static func slideshowFinished(page: Int, entryCount: Int, alreadyCelebrated: Bool) -> Bool {
    !alreadyCelebrated && entryCount > 0 && page == entryCount - 1
  }

  static func showsSlideshowProgress(entryCount: Int) -> Bool {
    entryCount > 3
  }

  static func celebratesSlideshow(page: Int, entryCount: Int, alreadyCelebrated: Bool) -> Bool {
    showsSlideshowProgress(entryCount: entryCount)
      && slideshowFinished(page: page, entryCount: entryCount, alreadyCelebrated: alreadyCelebrated)
  }
}
