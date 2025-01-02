#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <peekpoke.h>

#define LINE_BUFF_SIZE 512
char line_buff[LINE_BUFF_SIZE];

char *first_line_ptr;

char *file_names_list[64];
unsigned file_names_len = 0;

int parse_options(int, char **);
char *new_str_node(char *);
int sort_file(FILE *);
char *insert_line_buff_into_list();
void display_output();
void usage(int);

// Modified by options
char *output_filename = NULL;
int sort_mult = 1;
int (*strcmp_ptr)(char *, char *) = strcmp;

int main(int argc, char *argv[]) {
	FILE *fp;
	unsigned i;

	parse_options(argc, argv);
	
	if (file_names_len) {
		for (i = 0; i < file_names_len; ++i) {
			fp = fopen(file_names_list[i], "r");
			if (fp) {
				sort_file(fp);
				fclose(fp);
			} else {
				fprintf(stderr, "sort: unable to open file '%s'\n", file_names_list[i]);
				exit(1);
			}
		}
	} else {
		fp = stdin;
		sort_file(fp);
	}
	
	display_output();
	
	return 0;
}

int parse_options(int argc, char *argv[]) {
	file_names_len = 0;
	
	(void)argc;	
	while (*(++argv)) {
		static char *curr_arg;
		curr_arg = *argv;
		
		if (curr_arg[0] == '-') {
			if (!strcmp(curr_arg,"-")) {
				file_names_list[file_names_len] = "#stdin";
				++file_names_len;
			} else if (!strcmp(curr_arg,"-f")) {
				strcmp_ptr = stricmp;
			} else if (!strcmp(curr_arg,"-o")) {
				char *next_arg = *(argv + 1);
				if (next_arg) {
					output_filename = next_arg;
				} else {
					printf("sort: option '%s' must be followed by argument\n", curr_arg);
				}
				++argv;
			} else if (!strcmp(curr_arg,"-r")) {
				sort_mult = -1;
			} else if (!strcmp(curr_arg,"--help")) {
				usage(0);
			} else {
				fprintf(stderr, "sort: invalid option '%s'\n", curr_arg);
				usage(1);
			}
		} else {
			file_names_list[file_names_len] = curr_arg;
			++file_names_len;
		}
	}
	
	return 0;
}

void usage(int status) {
	fputs("Usage: sort [OPTIONS] [FILES]\n"
		"\n"
		"Options:\n"
		"  -f: Use a case-insenstive comparison\n"
		"  -o OUTPUT: Specify the an output file to be used instead of stdout\n"
		"  -r: Reverse the sense of comparisons\n"
		"  --help: Print this message and exit\n"
		"\n"
		"If no FILES are specified, read from stdin\n"
		, stderr);
	exit(status);
}

char *new_str_node(char *s) {
	char *m = malloc(3 + strlen(s));
	if (!m) {
		fputs("sort: error allocating memory", stderr);
		exit(1);
	}
	
	*((char **)m) = NULL;
	strcpy(m + 2, s);
	
	return m;
}

char *insert_line_buff_into_list() {
	static char *curr_line_ptr, *last_line_ptr;
	static char *n;
	
	if (first_line_ptr == NULL) {
		first_line_ptr = new_str_node(line_buff);
		return first_line_ptr;
	}
	
	last_line_ptr = NULL;
	curr_line_ptr = first_line_ptr;
	while (curr_line_ptr) {
		if (strcmp_ptr(line_buff, curr_line_ptr + 2) * sort_mult < 0) {
			n = new_str_node(line_buff);
			if (last_line_ptr != NULL) {
				*((char **)last_line_ptr) = n;
			} else {
				first_line_ptr = n;
			}
			*((char **)n) = curr_line_ptr;
			return n;
		}		
		last_line_ptr = curr_line_ptr;
		curr_line_ptr = *((char **)curr_line_ptr);
	}
	n = new_str_node(line_buff);
	*((char **)last_line_ptr) = n;
	return n;
}

int sort_file(FILE *fp) {		
	while (fgets(line_buff, LINE_BUFF_SIZE, fp) != NULL) {
		char *lfptr = strchr(line_buff, '\n');
		if (lfptr) *lfptr = '\0';
		
		insert_line_buff_into_list();
	}
	
	return 0;
}

void display_output() {
	static char *curr_line_ptr;
	FILE *output_fp;
	
	if (output_filename) {
		output_fp = fopen(output_filename, "w");
		if (!output_fp) {
			fprintf(stderr, "sort: unable to open file '%s' for writing\n", output_filename);
			exit(1);
		}
	} else {
		output_fp = stdout;
	}
	
	for (curr_line_ptr = first_line_ptr; curr_line_ptr; curr_line_ptr = *((char **)curr_line_ptr)) {
		fprintf(output_fp, "%s\n", curr_line_ptr + 2);
	}
	
	fclose(output_fp);
}
