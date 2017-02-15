/*
 * simecho.h
 *
 *  Created on: Feb 9, 2017
 *      Author: joelai
 */

#ifndef TEST_SIMECHO_SIMECHO_H_
#define TEST_SIMECHO_SIMECHO_H_

#include <moss/util.h>
#include <moss/net.h>

#define LOG_LEVEL_ERROR 8
#define _sim_log_dbg(lvl, tag, ...) do { \
	sim_log_dbg(lvl, tag, __func__, __LINE__, __VA_ARGS__); \
} while(0)
#define sim_log_error(...) _sim_log_dbg(LOG_LEVEL_ERROR, LOG_TAG, __VA_ARGS__)
#define sim_log_debug(...) _sim_log_dbg(LOG_LEVEL_ERROR + 2, LOG_TAG, __VA_ARGS__)

int sim_log_dbg(int lvl, const char *tag, const char *fname, int lno,
		const char *fmt, ...) __attribute__((format(printf, 5, 6)));

#endif /* TEST_SIMECHO_SIMECHO_H_ */
