enum Celebration {
  static func slideshowFinished(page: Int, entryCount: Int, alreadyCelebrated: Bool) -> Bool {
    !alreadyCelebrated && entryCount > 0 && page == entryCount - 1
  }

  static func showsSlideshowChrome(entryCount: Int) -> Bool {
    entryCount > 3
  }
}
