import AppKit

final class SoundPlayer {
    enum Sound: String, CaseIterable {
        case applause
        case destroyGroup = "destroy_group"
        case hurry
        case launch
        case lose
        case newRoot = "newroot_solo"
        case noh
        case rebound
        case stick
        case typewriter
    }

    enum Music: String {
        case intro = "introzik"
        case onePlayer = "frozen-mainzik-1p"
        case twoPlayer = "frozen-mainzik-2p"
    }

    private var sounds: [Sound: NSSound] = [:]
    private var music: NSSound?
    private var currentMusic: Music?
    var soundEnabled = true
    var musicEnabled = true {
        didSet {
            if !musicEnabled {
                music?.pause()
            } else if let currentMusic {
                playMusic(currentMusic, restart: music == nil)
            }
        }
    }

    init() {
        for sound in Sound.allCases {
            guard let url = GameResources.bundle.url(
                forResource: sound.rawValue,
                withExtension: "au",
                subdirectory: "Resources/Sounds"
            ), let nsSound = NSSound(contentsOf: url, byReference: false) else {
                continue
            }
            nsSound.volume = 0.75
            sounds[sound] = nsSound
        }
    }

    func play(_ sound: Sound) {
        guard soundEnabled else { return }
        guard let nsSound = sounds[sound] else { return }
        if nsSound.isPlaying {
            nsSound.stop()
        }
        nsSound.currentTime = 0
        nsSound.play()
    }

    func playMusic(_ track: Music) {
        playMusic(track, restart: false)
    }

    func playMusic(_ track: Music, restart: Bool) {
        guard musicEnabled else {
            currentMusic = track
            return
        }
        if !restart, currentMusic == track, music?.isPlaying == true {
            return
        }

        music?.stop()
        guard let url = GameResources.bundle.url(
            forResource: track.rawValue,
            withExtension: "m4a",
            subdirectory: "Resources/Music"
        ), let nsSound = NSSound(contentsOf: url, byReference: false) else {
            return
        }

        nsSound.volume = 0.38
        nsSound.loops = true
        nsSound.play()
        music = nsSound
        currentMusic = track
    }

    func stopMusic() {
        music?.stop()
        music = nil
        currentMusic = nil
    }
}
