import re, sys

routines_file = open("../docs/routines.md")
routines_content = routines_file.read()
routines_file.close()

#
# routines.md
#
routines_content = routines_content[routines_content.find("## Function Reference"):]
entries = routines_content.split("### ")[1:]

#
# extmem.md
#
extmem_file = open("../docs/extmem.md")
extmem_content = extmem_file.read()
extmem_file.close()

address_dict = {}
table = [line for line in extmem_content.splitlines() if (len(line) > 0 and '|' == line[0] and '|' == line[-1])][2:]
for row in table:
    value = re.sub(r'.*\| (\$[A-Z0-9]+) \|.*', r'\1', row)
    key = re.sub(r'.*\[`([\w_]+)`\].*', r'\1', row)
    address_dict[key] = value

extmem_content = extmem_content[extmem_content.find("## Function Reference"):]
entries += extmem_content.split("### ")[1:]

#
# system_hooks.md
#
hooks_file = open("../docs/system_hooks.md")
hooks_content = hooks_file.read()
hooks_file.close()

hooks_content = hooks_content[hooks_content.find("## Function Reference"):]
entries += hooks_content.split("### ")[1:]

for entry in entries:
    address = None
    name = None
    first_line, _, rest = entry.partition("\n")
    if ':' in first_line:
        address, name = first_line.strip().split(": ")
    else:
        name = first_line.strip()
        if name in address_dict:
            address = address_dict[name]
        else:
            poss_addr_line = rest.partition("\n")[0].strip()
            if re.match(r'Call Address: \$[0-9A-F]+', poss_addr_line):
                address = poss_addr_line.partition(": ")[2]
                rest = rest.partition("\n")[2]
                
    
    #print(name + ": " + address)
    out = open("osfiles/usr/man/" + name + ".2", "w")
        
    print(".TH " + name + "(2),System Calls Manual," + name + "(2)", file=out)
    print(".SH ADDRESS", file=out)
    print(address, file=out)
    
    split_result = re.split("Return values", rest, maxsplit=1, flags=re.IGNORECASE)
    if len(split_result) < 2:
        split_result = re.split("- Returns ", rest, maxsplit=1, flags=re.IGNORECASE)
    if len(split_result) < 2:
        split_result = [rest, '- None\n---']
    description, rvals = split_result
    
    description = description.strip()
    description = re.sub(r'\[here\]\(([^\)]+)\)', 'ONLINE REFERENCE', description)
    description = re.sub(r'\[`?([^\]]+?)`?\]\((#[^\)]+)\)', r'\1(2)', description)
    description = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'\2', description)
    description = re.sub(r'\n+', '\n', description)
    
    args_split = description.split("Arguments:", 1)
    print(".SH DESCRIPTION", file=out)
    if len(args_split) == 1:
        print(description.replace("\n", "\n\n").strip(), file=out)
    else:
        description = args_split[0]
        print(description.replace("\n", "\n\n").strip(), file=out)
        print(".SH ARGUMENTS", file=out)
        print(args_split[1].replace("\n", "\n\n").strip(), file=out)
    print(".SH RETURN VALUES", file=out)
    rvals = rvals.partition("---")[0].strip()
    rvals = re.sub(r'\(?(.*)\)?:\n', r'\1\n', rvals).strip()
    print(rvals.replace("\n", "\n\n"), file=out)
    print("", file=out)
    
    out.close()
