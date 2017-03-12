/*
 * main.cpp
 *
 *  Created on: Mar 11, 2017
 *      Author: joelai
 */
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

#define ARRAYSIZE(_arr) (sizeof(_arr) / sizeof((_arr)[0]))

void delay(signed long ms) {
#define DELAY_LOOP(_du) \
	while (ms >= _du) { \
		_delay_ms(_du); \
		ms -= _du; \
		if (ms <= 0l) return; \
	}

	DELAY_LOOP(60000l);
	DELAY_LOOP(1000l);
	while (ms-- > 0l) {
		_delay_ms(1);
	}
}

void sw(int sw, int ms) {
	if (sw) {
		PORTC |= (1 << PINC7); /* PINC7 HIGH */
	} else {
		PORTC &= ~(1 << PINC7); /* PINC7 LOW */
	}
	delay(ms);
}

void init() {
	DDRC |= 1 << DDC7; /* PINC7 will now be the output pin */
}

int main(int, char **) {
	init();
	while (1) {
		sw(1, 200);
		sw(0, 100);
		sw(1, 200);
		sw(0, 500);
	}
	return 0;
}

ISR(TIMER1_OVF_vect) {

}
