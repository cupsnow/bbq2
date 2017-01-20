/*
 * rtmgrplink.c
 *
 *  Created on: Jan 16, 2017
 *      Author: joelai
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <fcntl.h>
#include <errno.h>

#include <asm/types.h>
#include <sys/socket.h>
#include <linux/netlink.h>

#define LOG(lvl, msg, ...) do { \
	printf(lvl "%s #%ld " msg, __func__, __LINE__, ##__VA_ARGS__); \
} while(0)
#define log_debug(msg, ...) LOG("Debug ", msg, ##__VA_ARGS__)
#define log_error(msg, ...) LOG("ERROR ", msg, ##__VA_ARGS__)

#define buf_data(buf) ((void*)((char*)(buf)->data + (buf)->pos))
#define buf_space(buf) ((buf)->cap - (buf)->pos - (buf)->lmt)
typedef struct {
	size_t pos, cap, lmt;
	void *data;
} buf_t;

static int buf_expand(buf_t *buf, size_t cap, int retain) {
	void *data;

	if (cap <= 0 || buf->cap >= cap) return 0;
	if (!(data = malloc(cap))) {
		return ENOMEM;
	}
	if (buf->data) {
		if (retain && buf->lmt > 0) {
			memcpy(data, buf_data(buf), buf->lmt);
		}
		free(buf->data);
	}
	buf->data = data;
	buf->cap = cap;
	return 0;
}

static int buf_append(buf_t *buf, void *data, size_t len) {

}

typedef struct {
	struct sockaddr_nl sa;
	int fd;
	long seq;
} nl_t;

static void nl_close(void *rec) {
	nl_t *nl = rec;

	if (nl->fd != -1) close(nl->fd);
	free(nl);
	return;
}

static int nl_open(void **rec) {
	int r;
	nl_t *nl = NULL;

	if (!(nl = calloc(1, sizeof(*nl)))) return ENOMEM;
    if ((nl->fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE)) == -1) {
    	r = EIO;
    	goto finally;
    }

    nl->sa.nl_family = AF_NETLINK;
    nl->sa.nl_groups = RTMGRP_LINK | RTMGRP_IPV4_IFADDR | RTMGRP_IPV6_IFADDR;
//	nl_pid = 0 before bind for kernel take care of assigning unique value
//	linkmon->sa.nl_pid = getpid();
    if (bind(nl->fd, (struct sockaddr*)&nl->sa, sizeof(nl->sa)) != 0) {
    	r = errno;
    	goto finally;
    }
    *rec = nl;
    r = 0;
finally:
	if (r != 0 && nl) nl_close(nl);
	return r;
}

static int nl_req_dump(void *rec, unsigned type) {
	nl_t *nl = rec;
	struct sockaddr_nl sa;
	struct nlmsghdr nh;
	struct iovec iov = {&nh, sizeof(nh)};
	struct msghdr txmsg = {&sa, sizeof(sa), &iov, 1, NULL, 0, 0};

	memset(&sa, 0, sizeof(sa));
	sa.nl_family = AF_NETLINK;
	nh->nlmsg_len = sizeof(nh);
	nh->nlmsg_flags = NLM_F_DUMP | NLM_F_REQUEST;
	nh->nlmsg_seq = ++nl->seq;
	nh->nlmsg_type = type;

	sendmsg(fd, &msg, 0);

}

int main(int argc, char **argv) {
	int r;
	void *linkmon = NULL;

	if (nl_open(&linkmon) != 0) {
		goto finally;
	}




	r = 0;
finally:
	nl_close(linkmon);
	return r;
}



