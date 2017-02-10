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
#include <linux/rtnetlink.h>

#define MOSS_MIN(_a, _b) ((_a) <= (_b) ? (_a) : (_b))
#define MOSS_MAX(_a, _b) ((_a) >= (_b) ? (_a) : (_b))

#define log_out(level, fmt, ...) do { \
	printf(level "%s #%ld " fmt, __func__, __LINE__, __VA_ARGS__); \
} while(0)
#define log_error(...) log_out("ERROR ", __VA_ARGS__)
#define log_info(...) log_out("INFO ", __VA_ARGS__)
#define log_debug(...) log_out("Debug ", __VA_ARGS__)
#define log_verbose(...) log_out("verbose ", __VA_ARGS__)

typedef struct moss_buf_rec {
	size_t pos, cap, lmt;
	void *data;
} moss_buf_t;
#define moss_buf_data(buf) ((char*)(buf)->data + (buf)->pos)

int moss_buf_expand(moss_buf_t *buf, size_t cap, int retain) {
	void *data;
	if (cap <= 0 || buf->cap >= cap) return 0;
	if (!(data = malloc(cap))) {
		return ENOMEM;
	}
	if (buf->data) {
		if (retain && buf->lmt > 0) {
			int sz = MIN(buf->lmt, buf->cap - buf->pos);
			memcpy(data, moss_buf_data(buf), sz);
			if (buf->lmt > sz) {
				memcpy((char*)data + sz, buf->data, buf->lmt - sz);
			}
			buf->pos = 0;
		}
		free(buf->data);
	}
	buf->data = data;
	buf->cap = cap;
	return 0;
}

int moss_buf_append(moss_buf_t *buf, void *data, size_t sz) {
	int sz_max = sz > (buf->cap - buf->lmt) ? (buf->cap - buf->lmt) : sz;
	if (data && sz_max > 0) {
		char *data_pos = (char*)buf->data + buf->pos + buf->lmt;
		int data_sz;
		if (data_pos >= (char*)buf->data + buf->cap)
			data_pos -= buf->cap;
		data_sz = MIN(sz_max, (char*)buf->data + buf->cap - data_pos);
		memcpy(data_pos, data, data_sz);
		if (sz_max > data_sz) {
			memcpy(buf->data, (char*)data + data_sz, sz_max - data_sz);
		}
	}
	return sz - sz_max;
}

void moss_buf_drain(moss_buf_t *buf, size_t sz) {
	if ((ssize_t)sz < 0 || sz >= buf->lmt) {
		buf->lmt = 0;
		return;
	}
	if ((buf->pos += sz) >= buf->cap)
		buf->pos -= buf->cap;
	buf->lmt -= sz;
	return;
}

int moss_printf(const char *fmt, ...)
{
	int r;
	va_list ap;

	va_start(ap, fmt);
	r = moss_vprintf(fmt, ap);
	va_end(ap);
	return r;
}

int moss_showhex(const void *_s, size_t n, unsigned long a)
{
#define SHOWHEX_ASCII 1
#define SHOWHEX_ADDR_WIDTH 8 /* sizeof(char*) * 2 */
#define SHOWHEX_ADDR_FMT "%08lX"
#define SHOWHEX_ADDR_SP "        "

/*                   1         2         3         4                   1
 * 12345678 12345678901234567890123456789012345678901234567   1234567890123456
 *
 * 00007FFF 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F | 0123456789abcdef
 *          ----------------------------------------------- | ----------------
 * FFFFDDBE                                           1f 20 |               .
 * FFFFDDC0 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f 30 | !"#$%&'()*+,-./0
 */
	char ascii_sp[16]  = "----------------";
	int i, l;
	const unsigned char *s = (unsigned char*)_s;

	moss_printf(SHOWHEX_ADDR_FMT " 00 01 02 03 04 05 06 07 08 09"
			" 0A 0B 0C 0D 0E 0F", a >> 32);
	a = (a << 32) >> 32;

	if (SHOWHEX_ASCII) moss_printf(" | 0123456789ABCDEF");
	moss_printf("\n" SHOWHEX_ADDR_SP " -----------------------------"
			"------------------");

	for (i = l = 0; i < n; l++) {
		if ((l & 0x0f) == 0) {
			ascii_sp[0x10] = '\0';
			if (SHOWHEX_ASCII) moss_printf(" | %s", ascii_sp);
			moss_printf("\n" SHOWHEX_ADDR_FMT, (unsigned long)(a + i));
		}
		if ((l & 0x0f) != ((unsigned long)(a + i) & 0x0f)) {
			moss_printf("   ");
			if (SHOWHEX_ASCII) ascii_sp[l % 0x10] = ' ';
		} else {
			moss_printf(" %02x", s[i]);
			if (SHOWHEX_ASCII) {
				ascii_sp[l % 0x10] = (isprint(s[i]) ? s[i] : '.');
			}
			i++;
		}
	}

	if (SHOWHEX_ASCII && ((l & 0x0f) != 0)) {
		for (; ; l++) {
			if ((l & 0x0f) == 0) {
				ascii_sp[l % 0x11] = '\0';
				moss_printf(" | %s\n", ascii_sp);
				break;
			}
			moss_printf("   ");
			ascii_sp[l % 0x10] = ' ';
		}
	}

	moss_printf("\n");

	return 0;
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
//	nl_t *nl = rec;
//	struct sockaddr_nl sa;
//	struct nlmsghdr nh;
//	struct iovec iov = {&nh, sizeof(nh)};
//	struct msghdr txmsg = {&sa, sizeof(sa), &iov, 1, NULL, 0, 0};
//
//	memset(&sa, 0, sizeof(sa));
//	sa.nl_family = AF_NETLINK;
//	nh->nlmsg_len = sizeof(nh);
//	nh->nlmsg_flags = NLM_F_DUMP | NLM_F_REQUEST;
//	nh->nlmsg_seq = ++nl->seq;
//	nh->nlmsg_type = type;
//
//	sendmsg(fd, &msg, 0);

}

int main(int argc, char **argv) {
	int r;
	void *linkmon = NULL;

	if (nl_open(&linkmon) != 0) {
		goto finally;
	}

	{
		moss_buf_t buf;

		memset(&buf, 0, sizeof(buf));
		moss_buf_expand(&buf, 5, 0);
		moss_buf_append(&buf, "12", 2);
		moss_showhex(buf->data, 5, 0);
		moss_buf_append(&buf, "ab", 2);
		moss_showhex(buf->data, 5, 0);
		moss_buf_expand(&buf, 7, 1);
		moss_buf_append(&buf, "ABCDE", 2);
		moss_showhex(buf->data, 7, 0);
	}


	r = 0;
finally:
	nl_close(linkmon);
	return r;
}



