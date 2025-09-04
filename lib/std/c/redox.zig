const std = @import("../std.zig");
const assert = std.debug.assert;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

pub const AT = struct {
    pub const FDCWD = -100;
    pub const REMOVEDIR = 0x200; // TODO: Not working
    pub const SYMLINK_NOFOLLOW = 0x100; // TODO: Not working
    pub const AT_EMPTY_PATH = 0x1000; // TODO: Not working
};

pub const DT = struct {
    pub const UNKNOWN = 0;
    pub const FIFO = 1;
    pub const CHR = 2;
    pub const DIR = 4;
    pub const BLK = 6;
    pub const REG = 8;
    pub const LNK = 10;
    pub const SOCK = 12;
    pub const WHT = 14;
};

pub const MADV = struct {
    pub const NORMAL = 0;
    pub const RANDOM = 1;
    pub const SEQUENTIAL = 2;
    pub const WILLNEED = 3;
    pub const DONTNEED = 4;
};

pub const POLL = struct {
    pub const IN = 0x001;
    pub const PRI = 0x002;
    pub const OUT = 0x004;
    pub const ERR = 0x008;
    pub const HUP = 0x010;
    pub const NVAL = 0x020;
    pub const RDNORM = 0x040;
    pub const RDBAND = 0x080;
    pub const WRNORM = 0x100;
    pub const WRBAND = 0x200;
};

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

pub const SHUT = struct {
    pub const RD = 0;
    pub const WR = 1;
    pub const RDWR = 2;
};

pub const SIG = struct {
    pub const BLOCK = 0;
    pub const UNBLOCK = 1;
    pub const SETMASK = 2;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
    pub const BUS = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const USR1 = 10;
    pub const SEGV = 11;
    pub const USR2 = 12;
    pub const PIPE = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const STKFLT = 16;
    pub const CHLD = 17;
    pub const CONT = 18;
    pub const STOP = 19;
    pub const TSTP = 20;
    pub const TTIN = 21;
    pub const TTOU = 22;
    pub const URG = 23;
    pub const XCPU = 24;
    pub const XFSZ = 25;
    pub const VTALRM = 26;
    pub const PROF = 27;
    pub const WINCH = 28;
    pub const IO = 29;
    pub const POLL = 29;
    pub const PWR = 30;
    pub const SYS = 31;
    pub const UNUSED = SIG.SYS;
};

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const CLOEXEC = 0o2000000;
    pub const NONBLOCK = 0o4000;
};

// networking

pub const in_port_t = u16;
pub const sa_family_t = u16;
pub const socklen_t = u64;

pub const PF = struct {
    pub const UNSPEC = 0;
    pub const LOCAL = 1;
    pub const UNIX = LOCAL;
    pub const INET = 2;
    pub const INET6 = 10;
};

pub const AF = struct {
    pub const UNSPEC = PF.UNSPEC;
    pub const LOCAL = PF.LOCAL;
    pub const UNIX = AF.LOCAL;
    pub const INET = PF.INET;
    pub const INET6 = PF.INET6;
};

pub const sockaddr = extern struct {
    family: sa_family_t,
    data: [14]u8,

    pub const SS_MAXSIZE = 128;
    pub const storage = extern struct {
        family: sa_family_t align(8),
        padding: [SS_MAXSIZE - @sizeOf(sa_family_t)]u8 = undefined,

        comptime {
            assert(@sizeOf(storage) == SS_MAXSIZE);
            assert(@alignOf(storage) == 8);
        }
    };

    /// IPv4 socket address
    pub const in = extern struct {
        family: sa_family_t = AF.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    /// IPv6 socket address
    pub const in6 = extern struct {
        family: sa_family_t = AF.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
    };

    /// UNIX domain socket address
    pub const un = extern struct {
        family: sa_family_t = AF.UNIX,
        path: [108]u8,
    };
};

pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    iovlen: usize,
    control: ?*anyopaque,
    controllen: usize,
    flags: u32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: usize,
    control: ?*const anyopaque,
    controllen: usize,
    flags: u32,
};

pub const epoll_data = extern union {
    ptr: usize,
    fd: i32,
    u32: u32,
    u64: u64,
};

pub const epoll_event = extern struct {
    events: u32,
    data: epoll_data,
};

// constants

pub const E = enum(u16) {
    /// No error occurred.
    /// Same code used for `NSROK`.
    SUCCESS = 0,
    /// Operation not permitted
    PERM = 1,
    /// No such file or directory
    NOENT = 2,
    /// No such process
    SRCH = 3,
    /// Interrupted system call
    INTR = 4,
    /// I/O error
    IO = 5,
    /// No such device or address
    NXIO = 6,
    /// Arg list too long
    @"2BIG" = 7,
    /// Exec format error
    NOEXEC = 8,
    /// Bad file number
    BADF = 9,
    /// No child processes
    CHILD = 10,
    /// Try again
    /// Also means: WOULDBLOCK: operation would block
    AGAIN = 11,
    /// Out of memory
    NOMEM = 12,
    /// Permission denied
    ACCES = 13,
    /// Bad address
    FAULT = 14,
    /// Block device required
    NOTBLK = 15,
    /// Device or resource busy
    BUSY = 16,
    /// File exists
    EXIST = 17,
    /// Cross-device link
    XDEV = 18,
    /// No such device
    NODEV = 19,
    /// Not a directory
    NOTDIR = 20,
    /// Is a directory
    ISDIR = 21,
    /// Invalid argument
    INVAL = 22,
    /// File table overflow
    NFILE = 23,
    /// Too many open files
    MFILE = 24,
    /// Not a typewriter
    NOTTY = 25,
    /// Text file busy
    TXTBSY = 26,
    /// File too large
    FBIG = 27,
    /// No space left on device
    NOSPC = 28,
    /// Illegal seek
    SPIPE = 29,
    /// Read-only file system
    ROFS = 30,
    /// Too many links
    MLINK = 31,
    /// Broken pipe
    PIPE = 32,
    /// Math argument out of domain of func
    DOM = 33,
    /// Math result not representable
    RANGE = 34,
    /// Resource deadlock would occur
    DEADLK = 35,
    /// File name too long
    NAMETOOLONG = 36,
    /// No record locks available
    NOLCK = 37,
    /// Function not implemented
    NOSYS = 38,
    /// Directory not empty
    NOTEMPTY = 39,
    /// Too many symbolic links encountered
    LOOP = 40,
    /// No message of desired type
    NOMSG = 42,
    /// Identifier removed
    IDRM = 43,
    /// Channel number out of range
    CHRNG = 44,
    /// Level 2 not synchronized
    L2NSYNC = 45,
    /// Level 3 halted
    L3HLT = 46,
    /// Level 3 reset
    L3RST = 47,
    /// Link number out of range
    LNRNG = 48,
    /// Protocol driver not attached
    UNATCH = 49,
    /// No CSI structure available
    NOCSI = 50,
    /// Level 2 halted
    L2HLT = 51,
    /// Invalid exchange
    BADE = 52,
    /// Invalid request descriptor
    BADR = 53,
    /// Exchange full
    XFULL = 54,
    /// No anode
    NOANO = 55,
    /// Invalid request code
    BADRQC = 56,
    /// Invalid slot
    BADSLT = 57,
    /// Bad font file format
    BFONT = 59,
    /// Device not a stream
    NOSTR = 60,
    /// No data available
    NODATA = 61,
    /// Timer expired
    TIME = 62,
    /// Out of streams resources
    NOSR = 63,
    /// Machine is not on the network
    NONET = 64,
    /// Package not installed
    NOPKG = 65,
    /// Object is remote
    REMOTE = 66,
    /// Link has been severed
    NOLINK = 67,
    /// Advertise error
    ADV = 68,
    /// Srmount error
    SRMNT = 69,
    /// Communication error on send
    COMM = 70,
    /// Protocol error
    PROTO = 71,
    /// Multihop attempted
    MULTIHOP = 72,
    /// RFS specific error
    DOTDOT = 73,
    /// Not a data message
    BADMSG = 74,
    /// Value too large for defined data type
    OVERFLOW = 75,
    /// Name not unique on network
    NOTUNIQ = 76,
    /// File descriptor in bad state
    BADFD = 77,
    /// Remote address changed
    REMCHG = 78,
    /// Can not access a needed shared library
    LIBACC = 79,
    /// Accessing a corrupted shared library
    LIBBAD = 80,
    /// .lib section in a.out corrupted
    LIBSCN = 81,
    /// Attempting to link in too many shared libraries
    LIBMAX = 82,
    /// Cannot exec a shared library directly
    LIBEXEC = 83,
    /// Illegal byte sequence
    ILSEQ = 84,
    /// Interrupted system call should be restarted
    RESTART = 85,
    /// Streams pipe error
    STRPIPE = 86,
    /// Too many users
    USERS = 87,
    /// Socket operation on non-socket
    NOTSOCK = 88,
    /// Destination address required
    DESTADDRREQ = 89,
    /// Message too long
    MSGSIZE = 90,
    /// Protocol wrong type for socket
    PROTOTYPE = 91,
    /// Protocol not available
    NOPROTOOPT = 92,
    /// Protocol not supported
    PROTONOSUPPORT = 93,
    /// Socket type not supported
    SOCKTNOSUPPORT = 94,
    /// Operation not supported on transport endpoint
    /// This code also means `NOTSUP`.
    OPNOTSUPP = 95,
    /// Protocol family not supported
    PFNOSUPPORT = 96,
    /// Address family not supported by protocol
    AFNOSUPPORT = 97,
    /// Address already in use
    ADDRINUSE = 98,
    /// Cannot assign requested address
    ADDRNOTAVAIL = 99,
    /// Network is down
    NETDOWN = 100,
    /// Network is unreachable
    NETUNREACH = 101,
    /// Network dropped connection because of reset
    NETRESET = 102,
    /// Software caused connection abort
    CONNABORTED = 103,
    /// Connection reset by peer
    CONNRESET = 104,
    /// No buffer space available
    NOBUFS = 105,
    /// Transport endpoint is already connected
    ISCONN = 106,
    /// Transport endpoint is not connected
    NOTCONN = 107,
    /// Cannot send after transport endpoint shutdown
    SHUTDOWN = 108,
    /// Too many references: cannot splice
    TOOMANYREFS = 109,
    /// Connection timed out
    TIMEDOUT = 110,
    /// Connection refused
    CONNREFUSED = 111,
    /// Host is down
    HOSTDOWN = 112,
    /// No route to host
    HOSTUNREACH = 113,
    /// Operation already in progress
    ALREADY = 114,
    /// Operation now in progress
    INPROGRESS = 115,
    /// Stale NFS file handle
    STALE = 116,
    /// Structure needs cleaning
    UCLEAN = 117,
    /// Not a XENIX named type file
    NOTNAM = 118,
    /// No XENIX semaphores available
    NAVAIL = 119,
    /// Is a named type file
    ISNAM = 120,
    /// Remote I/O error
    REMOTEIO = 121,
    /// Quota exceeded
    DQUOT = 122,
    /// No medium found
    NOMEDIUM = 123,
    /// Wrong medium type
    MEDIUMTYPE = 124,
    /// Operation canceled
    CANCELED = 125,
    /// Required key not available
    NOKEY = 126,
    /// Key has expired
    KEYEXPIRED = 127,
    /// Key has been revoked
    KEYREVOKED = 128,
    /// Key was rejected by service
    KEYREJECTED = 129,
    // for robust mutexes
    /// Owner died
    OWNERDEAD = 130,
    /// State not recoverable
    NOTRECOVERABLE = 131,
    _,
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const GETLK = 5;
    pub const SETLK = 6;
    pub const SETLKW = 7;
    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;
};

pub const O = packed struct {
    _0: u16 = 0, // prefix 16 bits
    ACCMODE: std.posix.ACCMODE = .RDONLY,
    NONBLOCK: bool = false,
    APPEND: bool = false,
    SHLOCK: bool = false,
    EXLOCK: bool = false,
    ASYNC: bool = false,
    SYNC: bool = false,
    CLOEXEC: bool = false,
    CREAT: bool = false,
    TRUNC: bool = false,
    EXCL: bool = false,
    DIRECTORY: bool = false,
    PATH: bool = false,
    _15: u1 = 0,
    NOFOLLOW: bool = false,
};

pub const S = struct {
    pub const IFMT = 0o170000;

    pub const IFDIR = 0o040000;
    pub const IFCHR = 0o020000;
    pub const IFBLK = 0o060000;
    pub const IFREG = 0o100000;
    pub const IFIFO = 0o010000;
    pub const IFLNK = 0o120000;
    pub const IFSOCK = 0o140000;

    pub const ISUID = 0o4000;
    pub const ISGID = 0o2000;
    pub const ISVTX = 0o1000;
    pub const IRUSR = 0o400;
    pub const IWUSR = 0o200;
    pub const IXUSR = 0o100;
    pub const IRWXU = 0o700;
    pub const IRGRP = 0o040;
    pub const IWGRP = 0o020;
    pub const IXGRP = 0o010;
    pub const IRWXG = 0o070;
    pub const IROTH = 0o004;
    pub const IWOTH = 0o002;
    pub const IXOTH = 0o001;
    pub const IRWXO = 0o007;

    pub fn ISREG(m: mode_t) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISDIR(m: mode_t) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISCHR(m: mode_t) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISBLK(m: mode_t) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISFIFO(m: mode_t) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISLNK(m: mode_t) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISSOCK(m: mode_t) bool {
        return m & IFMT == IFSOCK;
    }
};

pub const SA = struct {
    pub const NOCLDWAIT = 2;
    pub const SIGINFO = 0x02000000;
    pub const RESTART = 0x08000000;
    pub const RESETHAND = 0x20000000;
    pub const ONSTACK = 0x04000000;
    pub const NODEFER = 0x10000000;
    pub const RESTORER = 0x00000004;
    pub const NOCLDSTOP = 0x40000000;
};

pub const T = struct {
    pub const CGETS = 0x5401;
    pub const CSETS = 0x5402;
    pub const CSETSW = 0x5403;
    pub const CSETSF = 0x5404;
    pub const CSBRK = 0x5409;
    pub const CXONC = 0x540a;
    pub const CFLSH = 0x540b;
    pub const IOCSCTTY = 0x540e;
    pub const IOCGPGRP = 0x540f;
    pub const IOCSPGRP = 0x5410;
    pub const IOCGWINSZ = 0x5413;
    pub const IOCSWINSZ = 0x5414;
    pub const FIONREAD = 0x541b;
    pub const IOCINQ = FIONREAD;
    pub const FIONBIO = 0x5421;
    pub const IOCPKT_DATA = 0;
    pub const IOCPKT_FLUSHREAD = 1;
    pub const IOCPKT_FLUSHWRITE = 2;
    pub const IOCPKT_STOP = 4;
    pub const IOCPKT_START = 8;
    pub const IOCPKT_NOSTOP = 16;
    pub const IOCPKT_DOSTOP = 32;
    pub const IOCPKT_IOCTL = 64;

    pub const IOCSER_TEMT = 0x01;
};

pub const tcflag_t = c_uint;
pub const cc_t = u8;
pub const mode_t = usize;
pub const nfds_t = c_ulong;

pub const NCC = 8;
pub const NCCS = 32;
pub const NSIG = 32;

pub const V = enum(usize) {
    VEOF = 0,
    VEOL = 1,
    VEOL2 = 2,
    VERASE = 3,
    VWERASE = 4,
    VKILL = 5,
    VREPRINT = 6,
    VSWTC = 7,
    VINTR = 8,
    VQUIT = 9,
    VSUSP = 10,
    VSTART = 12,
    VSTOP = 13,
    VLNEXT = 14,
    VDISCARD = 15,
    VMIN = 16,
    VTIME = 17,
};

pub const W = struct {
    pub const NOHANG = 1;
    pub const UNTRACED = 2;
    pub const STOPPED = 2;
    pub const EXITED = 4;
    pub const CONTINUED = 8;
    pub const NOWAIT = 0x1000000;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast((s & 0xff00) >> 8));
    }
    pub fn TERMSIG(s: u32) u32 {
        return s & 0x7f;
    }
    pub fn STOPSIG(s: u32) u32 {
        return EXITSTATUS(s);
    }
    pub fn IFEXITED(s: u32) bool {
        return TERMSIG(s) == 0;
    }
    pub fn IFSTOPPED(s: u32) bool {
        return @as(u16, @truncate(((s & 0xffff) *% 0x10001) >> 8)) > 0x7f00;
    }
    pub fn IFSIGNALED(s: u32) bool {
        return (s & 0xffff) -% 1 < 0xff;
    }
};

pub const tc_iflag_t = packed struct(tcflag_t) {
    IGNBRK: bool = false,
    BRKINT: bool = false,
    IGNPAR: bool = false,
    PARMRK: bool = false,
    INPCK: bool = false,
    ISTRIP: bool = false,
    INLCR: bool = false,
    IGNCR: bool = false,
    ICRNL: bool = false,
    IXON: bool = false,
    IXOFF: bool = false,
    IXANY: bool = false,
};

pub const tc_oflag_t = packed struct(tcflag_t) {
    OPOST: bool = false,
    ONLCR: bool = false,
    OLCUC: bool = false,
    OCRNL: bool = false,
    ONOCR: bool = false,
    ONLRET: bool = false,
    OFILL: bool = false,
    OFDEL: bool = false,
};

pub const tc_cflag_t = packed struct(tcflag_t) {
    _0: u9,
    CSTOPB: bool = false,
    CREAD: bool = false,
    PARENB: bool = false,
    PARODD: bool = false,
    HUPCL: bool = false,
    CLOCAL: bool = false,
};

pub const tc_lflag_t = packed struct(tcflag_t) {
    _0: u7,
    ISIG: bool = false,
    ICANON: bool = false,
    XCASE: bool = false,
    ECHO: bool = false,
    ECHOE: bool = false,
    ECHOK: bool = false,
    ECHONL: bool = false,
    NOFLSH: bool = false,
    TOSTOP: bool = false,
    IEXTEN: bool = false,
};

pub const termios = extern struct {
    iflag: tc_iflag_t,
    oflag: tc_oflag_t,
    cflag: tc_cflag_t,
    lflag: tc_lflag_t,
    line: cc_t,
    cc: [NCCS]cc_t,
};

pub const speed_t = enum(usize) {
    B0 = 0x0000000,
    B50 = 0x0000001,
    B75 = 0x0000002,
    B110 = 0x0000003,
    B134 = 0x0000004,
    B150 = 0x0000005,
    B200 = 0x0000006,
    B300 = 0x0000007,
    B600 = 0x0000008,
    B1200 = 0x0000009,
    B1800 = 0x000000a,
    B2400 = 0x000000b,
    B4800 = 0x000000c,
    B9600 = 0x000000d,
    B19200 = 0x000000e,
    B38400 = 0x000000f,

    B57600 = 0x00001001,
    B115200 = 0x00001002,
    B230400 = 0x00001003,
    B460800 = 0x00001004,
    B500000 = 0x00001005,
    B576000 = 0x00001006,
    B921600 = 0x00001007,
    B1000000 = 0x00001008,
    B1152000 = 0x00001009,
    B1500000 = 0x0000100a,
    B2000000 = 0x0000100b,
    B2500000 = 0x0000100c,
    B3000000 = 0x0000100d,
    B3500000 = 0x0000100e,
    B4000000 = 0x0000100f,

    pub const EXTA = speed_t.B19200;
    pub const EXTB = speed_t.B38400;
};
