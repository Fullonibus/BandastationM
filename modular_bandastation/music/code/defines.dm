#define INSTRUMENT_OUTPUT_GAIN 2
#define INSTRUMENT_FILE_OUTPUT_GAIN 3
#define INSTRUMENT_FALLOFF_DISTANCE 4
#define INSTRUMENT_FALLOFF_EXPONENT 3
/// Bounds shared by instrument uploads and physical concert disks.
#define MUSIC_UPLOAD_MAX_BYTES (10 * 1024 * 1024)
#define MUSIC_UPLOAD_MAX_DURATION (30 MINUTES)
/// Capacity of one round-local physical disk.
#define CONCERT_DISK_MAX_TRACKS 12
#define CONCERT_DISK_MAX_BYTES (50 * 1024 * 1024)
/// Bounded number of linked sound origins per concert player.
#define CONCERT_MAX_RECEIVERS 16
/// Concert music stays non-positional within this Euclidean distance, inclusive.
#define CONCERT_STEREO_RADIUS 5
