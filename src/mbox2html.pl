#!/usr/bin/env perl
use strict;
use warnings;
use Mail::Box::Manager;
use HTML::Entities;
use Time::Piece;
use File::Path qw(make_path);
use Digest::MD5 qw(md5_hex);

my $mbox_dir = shift || die "Usage: $0 mbox_directory\n";
my $output_dir = "mbox_html";
make_path($output_dir);

my @index_entries;
my $mgr = Mail::Box::Manager->new;

foreach my $mbox_file (glob("$mbox_dir/*.mbox")) {
    my $folder = $mgr->open(folder => $mbox_file, type => 'mbox') 
        or die "Can't open $mbox_file: $!\n";

    foreach my $message ($folder->messages) {
        my $time = localtime($message->timestamp)->datetime;
        my $subject = $message->subject || '(No Subject)';
        my $from = $message->from || '(No Sender)';
        
        # Create unique filename using timestamp and md5 of content
        my $id = md5_hex($time . $subject . $from);
        my $filename = "$output_dir/msg_$id.html";
        
        # Store for index
        push @index_entries, {
            time => $time,
            subject => $subject,
            from => $from,
            file => "msg_$id.html"
        };

        # Write individual message file
        open(my $fh, '>', $filename) or die "Can't write $filename: $!";
        print $fh <<"HTML_HEAD";
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$subject</title>
    <style>
        body { font-family: monospace; margin: 2em; }
        .headers { 
            background: #e8e8e8;
            padding: 0.5em;
            margin-bottom: 1em;
        }
        .body { 
            white-space: pre-wrap;
            padding: 0.5em;
        }
        .time { color: #666; }
        a { color: #0066cc; }
    </style>
</head>
<body>
<a href="index.html">← Back to Index</a>
<div class='headers'>
<strong>Date:</strong> <span class='time'>$time</span><br>
<strong>From:</strong> @{[encode_entities($from)]}<br>
<strong>Subject:</strong> @{[encode_entities($subject)]}<br>
</div>
<div class='body'>
HTML_HEAD

        if ($message->body->isMultipart) {
            print $fh encode_entities($message->body->part(0)->decoded->string);
        } else {
            print $fh encode_entities($message->body->string);
        }

        print $fh "</div></body></html>\n";
        close $fh;
    }
    $folder->close;
}

# Create index file
open(my $index_fh, '>', "$output_dir/index.html") or die "Can't write index: $!";
print $index_fh <<'INDEX_HEAD';
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Request Tracker Mail</title>
    <style>
        body { font-family: monospace; margin: 2em; }
        table { 
            border-collapse: collapse;
            width: 100%;
        }
        th, td {
            text-align: left;
            padding: 8px;
            border-bottom: 1px solid #ddd;
        }
        tr:nth-child(even) { background-color: #f2f2f2; }
        tr:hover { background-color: #e8e8e8; }
        th { 
            background-color:rgb(175, 76, 76);
            color: white;
        }
        a { 
            color: #0066cc;
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
<h1>Request Tracker Mail Index</h1>
<table>
<tr><th>Date</th><th>From</th><th>Subject</th></tr>
INDEX_HEAD

# Sort messages by time, newest first
foreach my $entry (sort { $b->{time} cmp $a->{time} } @index_entries) {
    print $index_fh "<tr>\n";
    print $index_fh "<td>$entry->{time}</td>\n";
    print $index_fh "<td>", encode_entities($entry->{from}), "</td>\n";
    print $index_fh "<td><a href='$entry->{file}'>", 
                    encode_entities($entry->{subject}), "</a></td>\n";
    print $index_fh "</tr>\n";
}

print $index_fh "</table></body></html>\n";
close $index_fh;