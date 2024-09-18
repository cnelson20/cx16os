#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <peekpoke.h>

#define GET_TIME 0x9D9F
#define R0 0x02
#define R1 0x04
#define R2 0x06
#define R3 0x08

void parse_spec_char(char c);
void parse_date(char *date_str);

char default_format_str[] = "+%a %b %e %H:%M:%S %Z %Y";

short year;
char month;
char day;
char hour;
char minute;
char second;
char weekday;

int main(int argc, char *argv[]) {
	if (argc >= 3) {
		printf("date: extra operand '%s'\r", argv[2]);
		exit(1);
	} 
	
	// get date using OS routine
	__asm__ ("jsr %w", GET_TIME);
		
	year = 1900 + PEEK(R0);
	month = PEEK(R0 + 1);
	day = PEEK(R1);
	hour = PEEK(R1 + 1);
	minute = PEEK(R2);
	second = PEEK(R2 + 1);
	weekday = PEEK(R3 + 1);
	
	if (argc >= 2) {
		parse_date(argv[1]);
	} else {
		parse_date(default_format_str);
	}

    return 0;
}

void parse_date(char *date_str) {
	unsigned char c;
	
	if (*date_str != '+') {
		printf("date: invalid date '%s'\r", date_str);
		exit(1);
	}
	++date_str;
	
	while (c = *date_str) {
		if (c != '%') {
			putchar(c);
			++date_str;
			continue;
		}
		++date_str;
		if (!(*date_str)) {
			putchar('%');
			continue;
		}
		parse_spec_char(*date_str);		
		++date_str;
	}
	
	putchar ('\r');
}

char is_leap_year(short year) {
	if (year & 3) { return 0; } // if i % 4 != 0 return false
	if (year % 100) { return 1; } // if not multiple of 100, return true
	if (year % 400) { return 0; } // if multiple of 100 but not 400, return false
	return 1; // if mult of 400, return true
}

short month_sum_days[] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};

// For %j, %U, %V specifiers
short days_since_jan_1() {
	return month_sum_days[month - 1] + day + (month < 3 ? 0 : is_leap_year(year));
}

// For %U and %V specifiers
char week_of_year(char specifier) {
	static signed short day_thru_year;
	static signed short first_day_of_this_week;
	
	static signed char days_in_first_week;
	static signed short start_of_first_week;
	
	day_thru_year = days_since_jan_1();
	first_day_of_this_week = day_thru_year - weekday;
	days_in_first_week = ( (first_day_of_this_week + 5) % 7) + 1;
	
	if (specifier == 'V') {
		// Start of week is Monday, not Sun
		days_in_first_week = (days_in_first_week % 7) + 1;
	}
	
	if (specifier == 'V' && days_in_first_week >= 4) {
		// Start of week is Monday, not Sun
		start_of_first_week = days_in_first_week + 1 - 14;
	} else {
		if (days_in_first_week == 7) {
			start_of_first_week = 1 - 7;
		} else {
			start_of_first_week = days_in_first_week + 1 - 7;
		}
	}
	return ( (day_thru_year - start_of_first_week) / 7 );
}

char abbr_weekdays[][4] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
char abbr_months [][4] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

char weekdays[][10] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
char months[][10] = {"January", "February", "March", "April", "June", "July", "August", "September",
"October", "November", "December"};

void parse_spec_char(char c) {
	switch (c) {
		case 'a':
			printf("%s", abbr_weekdays[weekday]);
			break;
		case 'A':
			printf("%s", weekdays[weekday]);
		case 'b':
		case 'h':
			printf("%s", abbr_months[month - 1]);
			break;
		case 'B':
			printf("%s", months[month - 1]);
			break;
		// missing %c and %C
		case 'd':
			printf("%02d", day);
			break;
		case 'D':
		case 'x': // locale date representation
			printf("%02d/%02d/%02d", month, day, year);
			break;
		case 'e':
			printf("%2d", day);
			break;
		
		case 'H':
			printf("%02d", hour);
			break;
		case 'I':
			printf("%02d", (hour % 12) + 1);
			break;
		case 'j':
			printf("%03d", days_since_jan_1());
		case 'm':
			printf("%02d", month);
			break;
		case 'M':
			printf("%02d", minute);
			break;
		case 'p':
			printf(hour >= 12 ? "PM" : "AM");
			break;
		case 'r':
			printf("%02d : %02d : %02d %s", (hour % 12) + 1, minute, second, hour >= 12 ? "PM" : "AM");
			break;
		case 'S':
			printf("%02d", second);
			break;
		case 'T':
		case 'X':
			printf("%02d:%02d:%02d", hour, minute, second);
			break;
		case 'u':
			printf("%d", weekday == 0 ? 7 : weekday);
			break;
		case 'U':
			printf("%03d", week_of_year('U'));
			break;
		case 'V':
			printf("%03d", week_of_year('V'));
			break;
		case 'w':
			printf("%d", weekday);
			break;
		case 'y':
			printf("%d", year % 100);
			break;
		case 'Y':
			printf("%d", year);
			break;
		case 'Z':
			break; // no timezone, just break
			
		case 'n':
			putchar('\n');
			break;
		case 't':
			putchar('\t');
			break;
		default:
			putchar('%');
		case '%':
			putchar(c);
			break;
	}
}


