/*
 * main.cpp
 *
 *  Created on: Feb 14, 2017
 *      Author: joelai
 */
#include "simecho.h"
#include <iostream>
#include <string>
#include <cerrno>
#include <cstring>
#include <vector>

#define SIMECHO_LOG_TAG "simecho2-main"

static const char *pn_def = "org.jl.simecho2.ctrl";

class Str: public std::string {
public:
	Str(const char *fmt, ...) {
		if (!fmt || !(*fmt)) {
			clear();
			return;
		}
		va_list va;
		va_start(va, fmt);
		format(fmt, va);
		va_end(va);
	}

	Str(const char *fmt, va_list va) {
		format(fmt, va);
	}

	void format(const char *fmt, va_list va) {
		if (!fmt || !(*fmt)) {
			clear();
			return;
		}
		if (buf.empty()) buf.reserve(64);
		do {
			buf.clear();
			int r = vsnprintf(&buf[0], buf.capacity(), fmt, va);
			if (r >= 0 && r < buf.capacity()) break;
			buf.reserve(buf.capacity() * 2);
		} while(true);
		assign(&buf[0]);
	}

	void format(const char *fmt, ...) {
		if (!fmt || !(*fmt)) {
			clear();
			return;
		}
		va_list va;
		va_start(va, fmt);
		format(fmt, va);
		va_end(va);
	}

protected:
	std::vector<char> buf;

};


class Ex {
public:
	int eno, lno;
	std::string msg, fn;

	Ex(): eno(errno) {
		msg = std::strerror(this->eno); print();
	};
	Ex(int lno, std::string fn, int eno, std::string msg):
		lno(lno), fn(fn), eno(eno), msg(msg) {
		print();
	};
	void print(void) {
		if (!fn.empty()) std::cerr << fn << " #" << lno << " ";
		if (eno != 0) {
			std::cerr << std::strerror(eno) << "(" << eno << ")";
		}
		if (!msg.empty()) {
			if (eno != 0) std::cerr << "; ";
			std::cerr << msg;
		}
		else std::cerr << std::endl;
	};
};
#define EX(...) Ex(__LINE__, __func__, __VA_ARGS__)

class Socket {
public:
	int fd;
	bool close_on_exit;

	Socket(int fd): fd(fd), close_on_exit(false) {};
	virtual ~Socket() {
		if (close_on_exit && fd != -1) {
			log_debug("close fd\n");
			close(fd);
		}
	};

	void nonblock(bool en) {
		int r;

		if ((r = fcntl(fd, F_GETFL, NULL)) == -1) {
			throw EX(errno, "F_GETFL\n");
		}
		if (en) r |= O_NONBLOCK;
		else r &= (~O_NONBLOCK);
		if (fcntl(fd, F_SETFD, r) != 0) {
			throw EX(errno, "F_SETFD\n");
		}
	}

	void listen(int num) {
		if (::listen(fd, num) != 0) {
			throw EX(errno, "listen\n");
		}
	}

	virtual void connect(void) {throw EX(0, "not implement\n");}
	virtual void bind(void) {throw EX(0, "not implement\n");}
	virtual Socket* accept(void) {throw EX(0, "not implement\n");}

};

class LocalSocket: public Socket {
public:
	struct sockaddr_un sa;
	socklen_t sa_len;
	const char *path_name;
	bool abstract;

	LocalSocket(const char *path_name, bool as_path = false): Socket(-1) {
		memset(&sa, 0, sizeof(sa));
		sa.sun_family = AF_LOCAL;
		if (path_name) set_local_path(path_name, as_path);
		if ((fd = socket(sa.sun_family, SOCK_STREAM, 0)) == -1) {
			throw EX(errno, "create local socket\n");
		}
		close_on_exit = true;
	}

	void set_local_path(const char *path_name, bool abstract = false) {
		int off = !(this->abstract = (abstract & *path_name));
		while(!(*path_name)) path_name++;
		strncpy(&sa.sun_path[off], path_name, sa_path_sz() - off - 1);
		this->path_name = &sa.sun_path[off];
		sa_len = offsetof(struct sockaddr_un, sun_path) + off +
				strlen(this->path_name) + this->abstract;
	}

	virtual void bind(void) {
		if (::bind(fd, (struct sockaddr*)&sa, sa_len) != 0) {
			throw EX(errno, Str("bind to %s\n", path_name));
		}
	}

	virtual Socket* accept(void) {
		LocalSocket *socket = new LocalSocket();
		memset(&socket->sa, 0, socket->sa_len = sizeof(socket->sa));
		socket->sa_len--;
		socket->sa.sun_family = AF_LOCAL;
		if ((socket->fd = ::accept(fd, (struct sockaddr*)&socket->sa,
				&socket->sa_len)) == -1) {
			delete socket;
			throw EX(errno, "accept\n");
		}
//		if (socket->sa_len > offsetof(struct sockaddr_un, sun_path)) {
//			int off = socket->sa_len - offsetof(struct sockaddr_un, sun_path);
//			sim_log_debug("off: %d\n", off);
//		} else {
//			sim_log_debug("unnamed\n");
//		}
		socket->path_name = &socket->
				sa.sun_path[!(abstract = socket->sa.sun_path[0])];
		socket->close_on_exit = true;
		return socket;
	};

	virtual void connect(void) {
		if (::connect(fd, (struct sockaddr*)&sa, sa_len) != 0) {
			throw EX(errno, Str("connect to %s\n", path_name));
		}
	}

protected:
	LocalSocket(): Socket(-1) {};
	int sa_path_sz() {return sizeof(struct sockaddr_un) - offsetof(struct sockaddr_un, sun_path);}
};

static struct {
	moss_evm_t *evm;
	moss_ev_t *ev_comm, *ev_svc, *ev_tmr;
	const char *pn;
	int opt_svr, opt_path;
	Socket *sock_svr, *sock_comm;

} impl = {NULL};

static void comm_cb(moss_ev_t *ev, unsigned act, void *arg) {
	if (act & MOSS_EV_ACT_RD) {
		while(true) {
			int r;
			char buf[64];

			r = read(impl.sock_comm->fd, buf, sizeof(buf) - 1);
			if (r < 0) {
				r = errno;
				if (r == EAGAIN || r == EWOULDBLOCK || EINTR) goto finally;
				sim_log_error("read ctrl: %s\n", strerror(r));
				moss_evm_poll_loop_break(impl.evm);
				return;
			}
			if (r == 0) {
				sim_log_error("disconnected ctrl\n");
				moss_evm_poll_loop_break(impl.evm);
				return;
			}
			buf[r] = '\0';
			sim_log_debug("read %d bytes: %s\n", r, buf);
			if (!strstr(buf, "simecho_clk")) {
				write(impl.sock_comm->fd, buf, r);
			}
		}
		goto finally;
	}
	if (act & MOSS_EV_ACT_TM) {
		// server
		static int clk = 0;
		int r;
		char buf[64];
		struct timeval tv = {3, 0};

		snprintf(buf, sizeof(buf), "{\"simecho_clk\": %d}\n", ++clk);
		buf[sizeof(buf) - 1] = '\0';
		r = write(impl.sock_comm->fd, buf, strlen(buf));
		sim_log_debug("write %d bytes: %s\n", r, buf);
		moss_ev_poll_timeout(ev, &tv);
		goto finally;
	}
finally:
	moss_evm_poll_add(impl.evm, ev);
}

static void svc_cb(moss_ev_t *ev, unsigned act, void *arg) {
	if (act & MOSS_EV_ACT_RD) {
		impl.sock_comm = impl.sock_svr->accept();
		sim_log_debug("accepted from %s\n",
				dynamic_cast<LocalSocket*>(impl.sock_comm)->path_name);
		impl.sock_comm->nonblock(true);

		impl.ev_comm = moss_ev_poll_alloc(impl.sock_comm->fd, MOSS_EV_ACT_RD,
				comm_cb, NULL);
		moss_evm_poll_add(impl.evm, impl.ev_comm);

		impl.ev_tmr = moss_ev_poll_alloc(-1, MOSS_EV_ACT_TM,
				comm_cb, NULL);
		struct timeval tv = {0, 0};
		moss_ev_poll_timeout(impl.ev_tmr, &tv);
		moss_evm_poll_add(impl.evm, impl.ev_tmr);
	}
}

static int client_mode() {
	int r;

	impl.sock_comm = new LocalSocket(impl.pn, impl.opt_path);
	impl.sock_comm->nonblock(true);
	impl.sock_comm->connect();

	impl.ev_comm = moss_ev_poll_alloc(impl.sock_comm->fd, MOSS_EV_ACT_RD,
			comm_cb, NULL);
	moss_evm_poll_add(impl.evm, impl.ev_comm);
	r = 0;
finally:
	return r;
}

static int server_mode() {
	int r;

	impl.sock_svr = new LocalSocket(impl.pn, impl.opt_path);
	impl.sock_svr->nonblock(true);
	impl.sock_svr->bind();
	impl.sock_svr->listen(1);

	impl.ev_svc = moss_ev_poll_alloc(impl.sock_svr->fd, MOSS_EV_ACT_RD,
			svc_cb, NULL);
	moss_evm_poll_add(impl.evm, impl.ev_svc);
	r = 0;
finally:
	return r;
}

static const char *opt_short = "-:s::cp:P::h";
static struct option opt_long[] = {
	{"server", optional_argument, NULL, 's'},
	{"client", no_argument, NULL, 'c'},
	{"path", required_argument, NULL, 'p'},
	{"pathname", optional_argument, NULL, 'P'},
	{"help", no_argument, NULL, 'h'},
	{NULL, 0, NULL, 0},
};

static void help(const char *fn) {
	sim_log_debug("Show help\n"
	"COMMAND\n"
	"  %s [OPTIONS]\n"
	"\n"
	"OPTIONS\n"
	"  -s, --server[=RELAY]   Server(relay) mode[RELAY ipaddr]\n"
	"  -c, --client           Client mode[default]\n"
	"  -p, --path=PATH        Local socket path\n"
	"  -P, --pathname[=NAME]  Local socket path name[default, %s]\n"
	"  -h, --help             Show help\n",
	fn, pn_def);
}

int main(int argc, char **argv) {
	int r;

	for (int i = 0; i < argc; i++) {
		sim_log_debug("argv[%d/%d]: %s\n", i + 1, argc, argv[i]);
	}
	impl.evm = moss_evm_poll_alloc();

	{
		int opt_op, opt_idx;

		optind = 0;
		while((opt_op = getopt_long(argc, argv, opt_short, opt_long,
				&opt_idx)) != -1) {
			if (opt_op == 's' || opt_op == 'c') {
				impl.opt_svr = opt_op == 's';
				continue;
			}
			if (opt_op == 'p' || opt_op == 'P') {
				// file path
				impl.opt_path = opt_op == 'p';
				impl.pn = optarg;
				continue;
			}
			if (opt_op == 'h') {
				help(argv[0]);
				goto finally;
			}
		}
	}
	if (!impl.pn || !impl.pn[0]) {
		impl.opt_path = 0;
		impl.pn = pn_def;
	}
	sim_log_debug("Summary\n"
	"Running mode: %s\n"
	"Local socket: %s, %s\n",
	impl.opt_svr ? "Server" : "Client",
	impl.opt_path ? "Path" : "Name", impl.pn);

	if (impl.opt_svr) {
		r = server_mode();
	} else {
		r = client_mode();
	}
	if (r != 0) goto finally;
	moss_evm_poll_loop(impl.evm);
	r = 0;
finally:
	return 0;

}

