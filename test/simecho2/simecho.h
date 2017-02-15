/*
 * simecho.h
 *
 *  Created on: Feb 14, 2017
 *      Author: joelai
 */

#ifndef _H_SIMECHO
#define _H_SIMECHO

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <getopt.h>

#include <event.h>

#include <moss/util.h>
#include <moss/net.h>

//#define _log_msg(lvl, msg, ...) do { \
//	printf(lvl "%s #%d " msg, __func__, __LINE__, ##__VA_ARGS__); \
//} while(0)
//#define log_error(...) _log_msg("ERROR ", __VA_ARGS__)
//#define log_debug(...) _log_msg("Debug ", __VA_ARGS__)

#define SIMECHO_LOG_ERROR 5
#define _sim_log_msg(lvl, msg, ...) do { \
	simecho_log_msg(lvl, SIMECHO_LOG_TAG, __func__, __LINE__, msg, ##__VA_ARGS__); \
} while(0)
#define sim_log_error(...) _sim_log_msg(SIMECHO_LOG_ERROR, __VA_ARGS__)
#define sim_log_info(...) _sim_log_msg(SIMECHO_LOG_ERROR + 1, __VA_ARGS__)
#define sim_log_debug(...) _sim_log_msg(SIMECHO_LOG_ERROR + 2, __VA_ARGS__)
#define sim_log_verbose(...) _sim_log_msg(SIMECHO_LOG_ERROR + 3, __VA_ARGS__)

#define SIMECHO_ARRAY_SIZE(arr) (sizeof(arr) / sizeof(arr[0]))

int simecho_log_msg(int lvl, const char *tag, const char *func, int lno,
		const char *fmt, ...) __attribute__((format(printf, 5, 6)));


#endif /* _H_SIMECHO */
