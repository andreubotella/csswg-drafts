#!/usr/bin/awk
#
# Takes a compact issues list in plain text and expands it to an HTML
# document. The issues list is line-based. Lines that start neither
# with "Issue" nor with a keyword and a colon are ignored. The lines
# are grouped into issues: each occurrence of "Issue:" starts a new
# issue. The following keywords are recognized:
#
# Draft
#   Must only occur once. The draft that these issues apply to. The
#   value must be a URL that ends with <status>-<shortname>-<YYYYMMDD>
#   and an optional slash.
#
# Issue
#   The issue number. The colon is optional after "Issue". Typically a
#   number, but may be anything. Must be unique.
#
# Summary
#   A short summary of the issue. May occur multiple times per
#   issue. Each occurrence adds a paragraph to the summary.
#
# From
#   The person who raised the issue. May occur multiple times per
#   issue.
#
# Comment
#   A URL pointing to (a part of) the comment. May occur multiple
#   times per issue. (Usually a pointer to a message on www-style.)
#
# Proposal
#   A proposed answer for the WG to discuss. May occur multiple times
#   per issue. This field is only printed if the issue is still open
#   (i.e., has no "Closed" field.)
#
# Response
#   A URL pointing to an answer that the WG sent to the commenter.
#   (Usually a pointer to a message on www-style.) May occur multiple
#   times per issue. Comment and Response lines should occur in date
#   order: for each issue, older comments and responses should be
#   listed before newer ones.
#
# Closed
#   The WG's resolution. Can be "Accepted," "Rejected," "OutOfScope,"
#   "Retracted" or "Invalid." May occur only once per issue.
#
# Verified
#   URL pointing to a message in which the commenter accepts the WG's
#   resolution. (Typically omitted for issues that are "Accepted.") 
#   Should only occur multiple times if there are multiple From lines.
#
# Objection
#   URL pointing to a message in which the commenter rejects the WG's
#   resolution. Should only occur multiple times if there are
#   multiple From lines.
#
# Author: Bert Bos <bert@w3.org>
# Created: 13 March 2012
# Copyright: © 2012 World Wide Web Consortium
# See http://www.w3.org/Consortium/Legal/2002/copyright-software-20021231


BEGIN {nerrors = 0; n = 0; IGNORECASE = 1}

/^draft[ \t]*:/ {draft = val($0); next}
/^issue\>/ {h = val($0); if (h in id) err("Duplicate issue number: " h); id[++n] = h; next}
n && /^summary[ \t]*:/ {summary[n] = summary[n] "<p>" val($0); next}
n && /^comment[ \t]*:[ \t]*http:/ {link[n] = link[n] "<li><a href=\"" val($0) "\">comment</a>\n"; next}
n && /^comment[ \t]*:/ {link[n] = link[n] "<li>" val($0) "\n"; next}
n && /^response[ \t]*:[ \t]*http:/ {link[n] = link[n] "<li><a href=\"" val($0) "\">reply</a>\n"; next}
n && /^response[ \t]*:/ {link[n] = link[n] "<li>" val($0) "\n"; next}
n && /^from[ \t]*:/ {from[n] = (from[n] ? from[n] "<br>" : "") val($0); next}
n && /^proposal[ \t]*:/ {proposal[n] = proposal[n] "<p class=proposal>" val($0); next}
n && /^closed[ \t]*:[ \t]* accepted\>/ {status[n] = "accepted"; next}
n && /^closed[ \t]*:[ \t]* outofscope\>/ {status[n] = "outofscope"; next}
n && /^closed[ \t]*:[ \t]* invalid\>/ {status[n] = "invalid"; next}
n && /^closed[ \t]*:[ \t]* rejected\>/ {status[n] = "rejected"; next}
n && /^closed[ \t]*:[ \t]* retracted\>/ {status[n] = "retracted"; next}
n && /^closed[ \t]*:/ {err("Unrecognized resolution \"" val($0) "\"."); next}
n && /^verified[ \t]*:/ {verif[n] = verif[n] "<a href=\"" val($0) "\">verified</a> "; next}
n && /^objection[ \t]*:/ {obj[n] = obj[n] "<a href=\"" val($0) "\">objection</a> "; next}
n && /^[a-z]+[ \t]*:/ {err("Unrecognized keyword \"" $1 "\"."); next}
/^[a-z]+[ \t]*:/ {err("Incorrect keyword \"" $1 "\" before first issue.")}

END {generate(); exit nerrors}


# generate -- generate the HTML file with all the issues
function generate(	command, title, date, class, nobjections, i)
{
  if (draft) {
    command = "hxnormalize -l 10000 -x " draft " | hxselect -c -s '\n' title";
    command | getline title;
    date = gensub("^.*-([0-9][0-9][0-9][0-9])([0-9][0-9])([0-9][0-9])/?$", \
                  "\\1-\\2-\\3", 1, draft);
  }

  if (!title) title = draft;
  if (!title) title = "[unknown]";
  if (!date) date = "[unknown]";

  print "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\">";
  print "<html lang=en>";
  print "<title>Disposition of Comments for “" title "” of " date "</title>";
  print "<meta http-equiv=content-type content=\"text/html; charset=utf-8\">\n";
  print "<style type=\"text/css\">";
  print "body {background: white; color: black}";
  print ".incomplete {background: lavender}";
  print ".proposal {font-style: italic}";
  print ".proposal:before {content: \"Proposal: \"; font-weight: bold}";
  print "table {border-collapse: collapse}";
  print "thead {background: gray; color: white}";
  print "tr {border-bottom: solid thin white}";
  print "th, td {text-align: left; padding: 0.5em; vertical-align: baseline}";
  print "td > *:first-child {margin-top: 0}";
  print "td > *:last-child {margin-bottom: 0}";
  print ".legend {font-size: smaller}";
  print ".ok {background: lightgreen}";
  print ".objection {background: red}";
  print ".unverified {background: orange}";
  print "</style>\n";
  print "<h1>Disposition of comments</h1>\n";
  print "<dl>";
  print "<dt>Title <dd>" title;
  print "<dt>Date <dd>" date;
  print "<dt>URL <dd><a href=\"" draft "\">" draft "</a>";
  print "</dl>\n";
  if (length(obj) == 0)
    print "<p>There are no objections.\n";
  else if (length(obj) == 1)
    print "<p class=objection>There is 1 objection.\n";
  else
    print "<p class=objection>There are " length(obj) " objections.\n";
  print "<table>";
  print "<thead>";
  print "<tr><th>#<th>Author<th>Summary and discussion<th>Result\n";
  print "<tbody>";

  for (i = 1; i <= n; i++) {
    printf "\n<tr class=";
    if (obj[i]) print "objection>";
    else if (verif[i] || status[i] ~ "accepted|retracted") print "ok>";
    else if (status[i]) print "unverified>";
    else print "incomplete>";
    print "<td id=x" i "><a href=\"#x" i "\">" id[i] "</a>";
    print "<td>" from[i];
    print "<td>" summary[i];
    if (link[i]) printf "<ol>\n%s</ol>\n", link[i];
    if (status[i]) printf "<td>%s", status[i];
    else if (proposal[i]) printf "<td>%s", proposal[i];
    else printf "<td><strong>[OPEN]</strong>";
    if (obj[i]) printf " but %s", obj[i];
    else if (verif[i]) printf " and %s", verif[i];
    else if (status[i] && status[i] !~ "accepted|retracted") printf " but unverified";
    printf "\n";
  }
  print "</table>\n";
  print "<p class=legend>Legend:\n";
  print "<table class=legend>";
  print "<thead>";
  print "<tr><th>Status<th>Meaning";
  print "<tbody>";
  print "<tr>\n<td class=ok>retracted";
  print "<td>Commenter has withdrawn the comment.";
  print "<tr>\n<td class=ok>accepted";
  print "<td>The WG accepted and applied the comment.";
  print "<tr>\n<td class=ok>out of scope and verified";
  print "<td>Commenter accepts that the comment is out of scope.";
  print "<tr>\n<td class=ok>invalid and verified";
  print "<td>Commenter accepts that the comment is invalid.";
  print "<tr>\n<td class=ok>rejected and verified";
  print "<td>Commenter accepts that the WG did not apply the comment.";
  print "<tr>\n<td class=unverified>out of scope but unverified";
  print "<td>Comment out of scope, but commenter did not yet react."
  print "<tr>\n<td class=unverified>invalid but unverified";
  print "<td>Comment invalid, but commenter did not yet react.";
  print "<tr>\n<td class=unverified>rejected but unverified";
  print "<td>Comment rejected, but commenter did not yet react.";
  print "<tr>\n<td class=objection>out of scope with objection";
  print "<td>Comment out of scope, but commenter disagrees.";
  print "<tr>\n<td class=objection>invalid with objection";
  print "<td>Comment invalid, but commenter disagrees.";
  print "<tr>\n<td class=objection>rejected with objection";
  print "<td>Comment rejected, but commenter objects.";
  print "</table>\n";
  print "<p>This file was generated from";
  print "<a href=\"" FILENAME "\">" FILENAME "</a>";
  print "on " strftime("%e %B %Y", systime(), 1) ".";
}


# esc -- escape HTML delimiters
function esc(s)
{
  gsub("&", "\\&amp;", s);
  gsub("<", "\\&lt;", s);
  gsub(">", "\\&gt;", s);
  gsub("\"", "\\&quot;", s);
  return s;
}


# val -- return the value part of the line s, as an HTML string
function val(s)
{
  return \
    esc(gensub("[ \t]+$", "", 1, gensub("^[a-z]+[ \t]*(:[ \t]*)?", "", 1, s)))
}


# err -- print an error message and increment the error count
function err(msg)
{
  print FILENAME ":" FNR ": " msg > "/dev/stderr";
  nerrors++;
}
