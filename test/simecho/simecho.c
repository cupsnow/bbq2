/*
 * simecho.cpp
 *
 *  Created on: Feb 9, 2017
 *      Author: joelai
 */

#include "simecho.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <getopt.h>

#define LOG_TAG "simecho-native"

int sim_log_dbg(int lvl, const char *tag, const char *fname, int lno,
		const char *fmt, ...) __attribute__((weak));
int sim_log_dbg(int lvl, const char *tag, const char *fname, int lno,
		const char *fmt, ...) {
	va_list ap;
	const char *lvl_str;

	switch(lvl - LOG_LEVEL_ERROR) {
	case 0:
		lvl_str = "ERROR ";
		break;
	case 1:
		lvl_str = "INFO ";
		break;
	case 2:
		lvl_str = "Debug ";
		break;
	case 3:
		lvl_str = "verbose ";
		break;
	default:
		lvl_str = "";
		break;
	}
	printf("%s %s %s #%d ", lvl_str, tag, fname, lno);

	if (fmt) {
		va_start(ap, fmt);
		vprintf(fmt, ap);
		va_end(ap);
	}
	return 0;
}

int sim_local_socket_open(const char *pn, int as_path,
		struct sockaddr_un *sa, socklen_t *sa_len) {
	int fd, off;
    struct sockaddr_un _sa;
    socklen_t _sa_len;

    if (!sa) sa = &_sa;
    if (!sa_len) sa_len= &_sa_len;
    *sa_len = sizeof(*sa);
	memset(sa, 0, *sa_len);
    sa->sun_family = AF_UNIX;
    off = !as_path;
    if (off > 0) memset(sa->sun_path, 0, off);
	strncpy(&sa->sun_path[off], pn, sizeof(sa->sun_path) - off);
	sa->sun_path[sizeof(sa->sun_path) - off - 1] = '\0';
    *sa_len = offsetof(struct sockaddr_un, sun_path) + off +
    		strlen(&sa->sun_path[off]);
    if ((fd = socket(sa->sun_family, SOCK_STREAM, 0)) == -1) {
    	int r = errno;
    	sim_log_error("open local socket %s %s: %s\n",
    			(as_path ? "path" : "name"), pn, strerror(r));
    	goto finally;
    }
finally:
    return fd;
}

static const char *pn_def = "org.jl.simecho.ctrl";

static struct {
	moss_evm_t *evm;
	moss_ev_t *ev_comm, *ev_svc, *ev_tmr;
	const char *pn;
	int opt_svr, opt_path, fd_svc, fd_comm;
	struct json_tokener *json_tokener;

} impl = {NULL};

static void comm_cb(moss_ev_t *ev, unsigned act, void *arg) {
	if (act & MOSS_EV_ACT_RD) {
		while(1) {
			int r;
			char buf[64];

			r = read(impl.fd_comm, buf, sizeof(buf) - 1);
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
				write(impl.fd_comm, buf, r);
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
		r = write(impl.fd_comm, buf, strlen(buf));
		sim_log_debug("write %d bytes: %s\n", r, buf);
		moss_ev_poll_timeout(ev, &tv);
		goto finally;
	}
finally:
	moss_evm_poll_add(impl.evm, ev);
}

static void svc_cb(moss_ev_t *ev, unsigned act, void *arg) {
	struct sockaddr_un sa;
    socklen_t sa_len = sizeof(sa);
    struct timeval tv = {0, 0};

    sim_log_debug("act: %d\n", act);

	if (act & MOSS_EV_ACT_RD) {
		memset(&sa, 0, sa_len);
		sa.sun_family = AF_LOCAL;
		impl.fd_comm = accept(impl.fd_svc, (struct sockaddr*)&sa, &sa_len);
		moss_file_nonblock(impl.fd_comm);
		impl.ev_comm = moss_ev_poll_alloc(impl.fd_comm, MOSS_EV_ACT_RD,
				comm_cb, NULL);
		moss_evm_poll_add(impl.evm, impl.ev_comm);

		impl.ev_tmr = moss_ev_poll_alloc(-1, MOSS_EV_ACT_TM,
				comm_cb, NULL);
		moss_ev_poll_timeout(impl.ev_tmr, &tv);
		moss_evm_poll_add(impl.evm, impl.ev_tmr);

	}
finally:
	moss_evm_poll_add(impl.evm, impl.ev_svc);
}

static int client_mode() {
	int r;
    struct sockaddr_un sa;
    socklen_t sa_len = sizeof(sa);

    if ((impl.fd_comm = sim_local_socket_open(impl.pn, impl.opt_path,
    		&sa, &sa_len)) == -1) {
    	goto finally;
    }
    moss_file_nonblock(impl.fd_svc);

	if (connect(impl.fd_comm, (struct sockaddr*)&sa, sa_len) != 0) {
		r = errno;
    	sim_log_error("connect ctrl: %s\n", strerror(r));
    	goto finally;
	}
    impl.ev_comm = moss_ev_poll_alloc(impl.fd_comm, MOSS_EV_ACT_RD | MOSS_EV_ACT_WR,
    		comm_cb, NULL);
    moss_evm_poll_add(impl.evm, impl.ev_comm);
    r = 0;
finally:
	return r;
}

static int server_mode() {
	int r, off;
    struct sockaddr_un sa;
    socklen_t sa_len = sizeof(sa);

    if ((impl.fd_svc = sim_local_socket_open(impl.pn, impl.opt_path,
    		&sa, &sa_len)) == -1) {
    	goto finally;
    }
    moss_file_nonblock(impl.fd_svc);

	if (bind(impl.fd_svc, (struct sockaddr*)&sa, sa_len) != 0) {
		r = errno;
    	sim_log_error("bind svc: %s\n", strerror(r));
    	goto finally;
	}

	if (listen(impl.fd_svc, 1) != 0) {
		r = errno;
    	sim_log_error("listen svc: %s\n", strerror(r));
    	goto finally;
	}

    impl.ev_svc = moss_ev_poll_alloc(impl.fd_svc, MOSS_EV_ACT_RD,
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
#define CMD_SVC "svc"
	int i, r;

	for (i = 0; i < argc; i++) {
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
