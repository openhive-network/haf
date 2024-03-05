import os
import subprocess
from typing import Iterable

import test_tools as tt

def run_and_get_output(*args: str) -> str:
    op_body_filter_path_from_envs = os.getenv("OP_BODY_FILTER_PATH", None)
    assert op_body_filter_path_from_envs is not None
    process = subprocess.run([op_body_filter_path_from_envs, *args], capture_output=True)

    if process.returncode:
        assert False, "Incorrect the `op_body_filter` tool response"
    return process.stdout.decode().strip()

def compare( output: Iterable[str], patterns: Iterable[str]):
    cnt = 0
    for row in patterns:
        assert row == output[cnt], f"Tool `op_body_filter` generated an incorrect output. Required: {row}, got: {output[cnt]}"
        cnt += 1

def test_find_transfers_greater_than_10_hive():
    tt.logger.info('Start `test_find_transfers_greater_than_10_hive` test')

    output = run_and_get_output(r"--op-type", r"transfer_operation", r"--op-body-regex", r"\"amount\":\"[0-9]{5,}\"", r"--ops-file", r"blocks/3286849.json")
    output = output.splitlines()

    patterns = [
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"allycat","amount":{"amount":"193255","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"dbal99","amount":{"amount":"14498","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"dennygalindo","amount":{"amount":"22133","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"domavila","amount":{"amount":"11040","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"ds90","amount":{"amount":"739398","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"phantomraviolis","amount":{"amount":"15716","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"sonsy","amount":{"amount":"27984","precision":3,"nai":"@@000000021"},"memo":""}}"""
    ]
    compare(output, patterns)

def test_find_transfers_greater_than_1_hive_less_than_10():
    tt.logger.info('Start `test_find_transfers_greater_than_1_hive_less_than_10` test')

    output = run_and_get_output(r"--op-type", r"transfer_operation", r"--op-body-regex", r"(\"to\":\"d)(.*)(\"amount\":\")([0-9]{4}\")", r"--ops-file", r"blocks/3286849.json")
    output = output.splitlines()

    patterns = [
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"decryptson","amount":{"amount":"2620","precision":3,"nai":"@@000000021"},"memo":""}}""",
        r"""{"type":"transfer_operation","value":{"from":"blocktrades","to":"domavila","amount":{"amount":"3140","precision":3,"nai":"@@000000021"},"memo":""}}"""
    ]
    compare(output, patterns)

def test_find_comments_with_filled_title():
    tt.logger.info('Start `test_find_comments_with_filled_title` test')

    output = run_and_get_output(r"--op-type", r"comment_operation", r"--op-body-regex", r"(\"title\")(\s*:\s*\")([A-Za-z0-9\s]+)(.*)(\"body\")", r"--ops-file", r"blocks/6531076.json")
    output = output.splitlines()

    patterns = [
        r"""{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"diary","author":"shla-rafia","permlink":"viva-la-steem-voting-power-on-75-using-better-steemvoter-and-robotev","title":"Viva La Steem: Voting power on 75%, using @better, @steemvoter and @robotev","body":"Hopefully there will be no double voting problems, let's see. \n\n@Steemvoter wrote that there could be a problem with low voting power and at the same time low steem power, let's see.\n\n@better is cool. Always more reward after I got featured.\n\n@Robotev is a friendly communicating bot and somehow votes like I vote, I would have to check again, but it's all a bit much now. My plan: Hope that nothing will break :-D\n\nStreet promo goes as usual. Many people a day make photos of the hat and the logo. Good mix of ~ 50 people a day.\n\nAmong the people today was a manager of a 'club of the year' from The Middle East. 2500 people party on the rooftop, daily. Now they will make a new one somewhere else. Rocknroll..\n\nI hear people are flocking into the city slowly. Maybe we'll meet and you can see me in action.\n\nI will check if the voting power goes up, otherwise pause everything until it's full again.\n\n\n@craig-grant makes good vids and I got  \nthe info about steemvoter from him.\n\nhttp://tinyimg.io/i/FyvKoBf.jpg\n\nA tourist from Mexico gave me a cigarette with a nice package. It's romantic compared to Marlboro and others.\n\nThanks for your support. Big thanks to the witnesses.","json_metadata":"{\"tags\":[\"diary\"],\"users\":[\"better\",\"craig-grant\"],\"image\":[\"http://tinyimg.io/i/FyvKoBf.jpg\"],\"app\":\"steemit/0.1\",\"format\":\"markdown\"}"}}""",
        r"""{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"life","author":"alexbeyman","permlink":"what-are-you-afraid-of","title":"What Are You Afraid Of?","body":"@@ -1787,16 +1787,40 @@\n vasion, \n+bear or shark attacks...\n still pr\n","json_metadata":"{\"tags\":[\"life\",\"philosophy\",\"writing\",\"spirituality\",\"emotion\"],\"image\":[\"http://i.imgur.com/ozfWGFn.jpg\",\"http://i.imgur.com/BfKPnbk.jpg\",\"http://i.imgur.com/bsBFCDE.jpg\",\"http://i.imgur.com/M9NBC7d.jpg\",\"http://i.imgur.com/GAodcHb.jpg\",\"http://i.imgur.com/o3wwfm6.jpg\",\"http://i.imgur.com/3AWmNnW.jpg\",\"http://i.imgur.com/MettJMG.jpg\"],\"app\":\"steemit/0.1\",\"format\":\"markdown\"}"}}""",
        r"""{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"religion","author":"pilgrimtraveler","permlink":"romans-10-9-i-believe-jesus-is-lord","title":"Romans 10:9  I Believe \"Jesus is Lord\"","body":"<html>\n<p><img src=\"https://scontent-sea1-1.xx.fbcdn.net/t31.0-8/13329426_10204866414259674_3246331287716173156_o.jpg\" width=\"2048\" height=\"1365\"/></p>\n<p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>I Believe!</strong></p>\n<p><br></p>\n<p>Romans 10:9 &nbsp;\"If you confess with your mouth that \"Jesus is Lord\" and Believe in your heart that God raised him from the dead you will be saved.\"</p>\n<p><br></p>\n<p><strong>&nbsp;How to be saved</strong></p>\n<p>&nbsp;For it is by believing in your heart that you are made right with God.&nbsp;</p>\n<p>&nbsp;By confessing with your mouth that you are saved.&nbsp;</p>\n<p>&nbsp;For u201cEveryone who calls on the name of the Lord will be saved.u201d&nbsp;</p>\n<p>&nbsp;Salvation through Jesus Christ brings us into a relationship of peace with God.&nbsp;</p>\n<p><strong>O might the God lead our hearts to love him and to rest in the Salvation of his Son. ~ Amen&nbsp;</strong></p>\n<p><br></p>\n<p>If you have come from my website, <a href=\"http://www.pilgrimtraveler.com/\">http://www.pilgrimtraveler.com&nbsp;</a></p>\n<p>Twitter,&nbsp;<a href=\"https://twitter.com/KarenGentry99\">https://twitter.com/KarenGentry99</a> &nbsp;</p>\n<p>Facebook, <a href=\"http://facebook.com/karenspassport\">http://facebook.com/karenspassport</a>&nbsp;</p>\n<p>Or any of my other social media channels, please consider getting your free account here on Steemit.&nbsp;</p>\n<p>You can follow all of the <a href=\"https://exploretraveler.com/\">ExploreTraveler Team</a> on Steemit <a href=\"https://steemit.com/@pilgrimtraveler\">@pilgrimtraveler</a> <a href=\"https://steemit.com/@exploretraveler\">@exploretraveler</a><a href=\"https://steemit.com/@karengentry\">@karengentry </a><a href=\"https://steemit.com/@johngentry\">@johngentry </a><a href=\"https://steemit.com/@vetvso\">@vetvso </a><a href=\"https://steemit.com/@johngentryjr\">@johngentryjr</a> <a href=\"https://steemit.com/@elijahgentry\">@elijahgentry </a><a href=\"https://steemit.com/@vetvso\">@vetvso</a><a href=\"https://steemit.com/@elijahgentry\"> </a><a href=\"https://steemit.com/@floridagypsy\">@floridagypsy</a> we will follow you back.</p>\n<p>&nbsp;<br>\n\"Join the adventure and be inspired.\" - Karen Gentry <a href=\"https://steemit.com/@pilgrimtraveler\">@pilgrimtraveler</a> &nbsp;&nbsp;&nbsp;</p>\n<p>&nbsp;&nbsp;Blessings from PilgrimTraveler!</p>\n<p>u00a9 2016 PilgrimTraveler. All Rights Reserved.<br>\n</p>\n<p>&nbsp;</p>\n</html>","json_metadata":"{\"tags\":[\"religion\",\"photography\",\"art\",\"scripture\",\"bible\"],\"image\":[\"https://scontent-sea1-1.xx.fbcdn.net/t31.0-8/13329426_10204866414259674_3246331287716173156_o.jpg\"],\"links\":[\"http://www.pilgrimtraveler.com/\",\"https://twitter.com/KarenGentry99\",\"http://facebook.com/karenspassport\",\"https://exploretraveler.com/\",\"https://steemit.com/@pilgrimtraveler\",\"https://steemit.com/@exploretraveler\",\"https://steemit.com/@karengentry\",\"https://steemit.com/@johngentry\",\"https://steemit.com/@vetvso\",\"https://steemit.com/@johngentryjr\",\"https://steemit.com/@elijahgentry\",\"https://steemit.com/@floridagypsy\"],\"app\":\"steemit/0.1\",\"format\":\"html\"}"}}""",
    ]
    compare(output, patterns)

def test_find_follow_for_particular_accounts():
    tt.logger.info('Start `test_find_follow_for_particular_accounts` test')

    output = run_and_get_output(r"--op-type", r"custom_json_operation", r"--op-body-regex", r"(\"id\")(\s*:\s*)(\"follow\")(\s*,\s*)(\"json\")(.*)(\\\"following)(.{1}\")(\s*:\s*)(.{1}\")((xiaokongcom)|(jfelton5))(.{1}\")", r"--ops-file", r"blocks/5771683.json")
    output = output.splitlines()

    patterns = [
        r"""{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["gamgam"],"id":"follow","json":"[\"follow\",{\"follower\":\"gamgam\",\"following\":\"jfelton5\",\"what\":[]}]"}}""",
        r"""{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["gamgam"],"id":"follow","json":"[\"follow\",{\"follower\":\"gamgam\",\"following\":\"xiaokongcom\",\"what\":[]}]"}}""",
    ]
    compare(output, patterns)
