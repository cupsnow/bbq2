/*
 * util.cpp
 *
 *  Created on: Feb 14, 2017
 *      Author: joelai
 */

#include "simecho.h"

int simecho_log_msg(int lvl, const char *tag, const char *func, int lno,
		const char *fmt, ...) __attribute__((weak));
int simecho_log_msg(int lvl, const char *tag, const char *func, int lno,
		const char *fmt, ...)
{
	const char *lvl_str;

	switch(lvl - SIMECHO_LOG_ERROR) {
	case 0:
		lvl_str = "ERROR";
		break;
	case 1:
		lvl_str = "INFO";
		break;
	case 2:
		lvl_str = "Debug";
		break;
	case 3:
		lvl_str = "verbose";
		break;
	default:
		lvl_str = NULL;
		break;
	}

	const char *lst[] = {
		lvl_str, tag, func
	};
	const char *pre = "";
	for (int i = 0; i < SIMECHO_ARRAY_SIZE(lst); i++) {
		if (lst[i]) {
			printf("%s%s", pre, lst[i]);
			pre = " ";
		}
	}
	if (lno >= 0) printf(" #%d", lno);

	if (fmt) {
		printf("%s", " ");
		va_list va;
		va_start(va, fmt);
		vprintf(fmt, va);
		va_end(va);
	}
	return 0;
}

