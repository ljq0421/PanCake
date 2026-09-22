"""64-second Chinese revision: Tianjin departure, earnings, unlocks and collection."""
from pathlib import Path
import json
import sys
sys.dont_write_bytecode = True
import render_steam_trailer as common

ROOT, OUT = common.ROOT, common.OUT
CAPTURES = OUT / 'work'
WORK = OUT / 'work64'
WORK.mkdir(parents=True, exist_ok=True)
common.WORK = WORK
run, draw = common.run, common.draw


def mark(shot, name, occurrence=0):
    rows = (CAPTURES / f'{shot}-marks.tsv').read_text(encoding='utf-8-sig').splitlines()
    return [float(r.split('\t')[0]) for r in rows if r.split('\t')[1] == name][occurrence]


def camera(kind, duration):
    count = round(duration * 30) - 1
    if kind == 'china':
        zoom, x, y = f'1.15+0.65*on/{count}', '.95', '.40'
    elif kind == 'unlock':
        zoom, x, y = f'1.2+0.40*on/{count}', '.95', '.43'
    elif kind == 'world':
        zoom, x, y = f'1.8-0.8*on/{count}', '.95', '.40'
    elif kind == 'income':
        zoom, x, y = f'1+0.15*on/{count}', '.72', '.45'
    elif kind == 'coins':
        zoom, x, y = '1.15', '.60', '0'
    else:
        return ''
    return f",scale=3840:2160,zoompan=z='{zoom}':x='(iw-iw/zoom)*{x}':y='(ih-ih/zoom)*{y}':d=1:s=1920x1080:fps=30"


def main():
    # shot, marker, occurrence, output duration, speed, camera, source offset
    cuts = [
        ('pages', 'title', 0, 2, 1, '', 1),
        ('journey', 'tianjin-map', 0, 3, 1, 'china', 0),
        ('tianjin', 'batter', 0, 3, 1.4, '', 0),
        ('tianjin', 'sauce', 0, 2.4, 1.4, '', 0),
        ('tianjin', 'fold', 0, 1.6, 1.3, '', 0),
        ('tianjin', 'stored_youtiao', 0, 2, 1, '', 0),
        ('rush', 'spread', 1, 2.2, 1.6, '', 0),
        ('rush', 'fold', 1, 2, 1.6, '', 0),
        ('rush', 'soy_milk_cup', 3, 2.8, 1, 'coins', 0),
        ('journey64', 'summary', 0, 6, 1, 'income', 0),
        ('pages', 'upgrade', 0, 5, 1, '', 1.5),
        ('journey', 'wuhan-unlock', 0, 5, 1, 'unlock', 0),
        ('wuhan', 'noodles-drop', 0, 3, 1.6, '', 0),
        ('wuhan', 'mix', 1, 2, 1.4, '', 0),
        ('wuhan', 'doupi-filling', 0, 3, 1.4, '', 0),
        ('wuhan', 'doupi-cut', 0, 2, 1, '', 0),
        ('journey', 'collection-tianjin', 0, 3, 1, '', 0),
        ('journey', 'collection-wuhan', 0, 3, 1, '', 0),
        ('journey', 'world-map', 0, 5, 1, 'world', 0),
    ]
    manifest, files, timeline = [], [], 0.0
    for i, (shot, action, occurrence, duration, speed, framing, offset) in enumerate(cuts):
        start = round((mark(shot, action, occurrence) + offset) * 30) / 30
        source, target = CAPTURES / f'{shot}.avi', WORK / f'cut-{i:02d}.mp4'
        signature = json.dumps([source.stat().st_mtime_ns, start, duration, speed, framing, 1])
        cache = target.with_suffix('.cache')
        if not target.exists() or not cache.exists() or cache.read_text() != signature:
            video = f'setpts=(PTS-STARTPTS)/{speed},fps=30'
            video += camera(framing, duration)
            video += ',scale=in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p,setsar=1,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709'
            audio = f'atempo={speed},volume=' + ('0' if shot == 'pages' else '.9')
            audio += f',afade=t=in:d=0.02,afade=t=out:st={duration-.04}:d=0.04'
            run(['-ss', start, '-i', source, '-t', duration, '-vf', video, '-af', audio,
                 '-r', 30, '-c:v', 'libx264', '-preset', 'fast', '-crf', 16, '-color_range', 'tv',
                 '-c:a', 'aac', '-b:a', '256k', '-ar', 48000, '-ac', 2, target], f'cut-{i:02d}.log')
            cache.write_text(signature)
        manifest.append(dict(start=round(timeline, 3), duration=duration, source=source.name,
                             source_start=start, speed=speed, camera=framing, action=action))
        timeline += duration
        files.append(target)
        print(f'CUT {i+1}/{len(cuts)} {action}', flush=True)
    assert abs(timeline - 58) < .001, timeline

    end = WORK / 'end.mp4'
    # Reuse the checked 60-second version's branded end card. Its six visible seconds retain the credits.
    run(['-i', CAPTURES / 'end.mp4', '-t', 6, '-c:v', 'copy', '-c:a', 'aac', '-ar', 48000, '-ac', 2, end], 'end.log')
    files.append(end)
    concat = WORK / 'concat.txt'
    concat.write_text('\n'.join("file '" + p.as_posix() + "'" for p in files), encoding='utf-8')
    run(['-f', 'concat', '-safe', 0, '-i', concat, '-c', 'copy', WORK / 'assembly.mp4'], 'assembly.log')

    captions = [
        (4.1, 6.8, '第一站，天津'),
        (7.2, 12.8, '从一份煎饼果子，开始早餐之旅'),
        (16.2, 21.9, '忙得过来，赚得开心'),
        (23.3, 28.6, '今天的努力，看得见'),
        (29.2, 33.7, '把小铺子，一点点经营起来'),
        (34.2, 38.7, '下一站，武汉过早'),
        (41.5, 48.5, '热干面、三鲜豆皮，都安排上'),
        (49.2, 54.7, '把每一份早餐，收进旅途'),
        (55.2, 59.7, '从天津出发，开启世界早餐之旅'),
    ]
    captions = [(begin - 2, finish - 2, text) for begin, finish, text in captions]
    filters = []
    for i, (begin, finish, text) in enumerate(captions):
        filters.append(draw(f'caption-{i}', text, 46, '(w-tw)/2', 995,
                            more=f":borderw=4:bordercolor=0x50311D:shadowcolor=0x50311D@0.45:shadowx=2:shadowy=3:enable='between(t,{begin},{finish})'"))
    graph = '[0:v]' + ','.join(filters) + '[v];'
    graph += '[1:a]atrim=duration=64,asetpts=PTS-STARTPTS,loudnorm=I=-21:LRA=9:TP=-3,afade=t=in:d=0.3,afade=t=out:st=61.5:d=2.5[music];'
    graph += '[0:a][music]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:LRA=9:TP=-1.5[a]'
    final = OUT / '全世界等我开饭-Steam宣传片-中文-64秒.mp4'
    run(['-i', WORK / 'assembly.mp4', '-ss', 24, '-i', ROOT / 'resource/audio/demo/Carefree.mp3',
         '-filter_complex', graph, '-map', '[v]', '-map', '[a]', '-t', 64, '-r', 30,
         '-c:v', 'libx264', '-preset', 'slow', '-b:v', '12M', '-minrate', '12M', '-maxrate', '12M', '-bufsize', '24M',
         '-x264-params', 'nal-hrd=cbr:filler=1', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1',
         '-color_range', 'tv', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
         '-c:a', 'aac', '-b:a', '256k', '-ar', 48000, '-ac', 2, '-movflags', '+faststart', final], 'final-encode.log')
    (OUT / 'edit-timeline-64.json').write_text(json.dumps(dict(duration=64, fps=30, cuts=manifest, captions=captions,
        end_card=dict(start=58, duration=6)), ensure_ascii=False, indent=2), encoding='utf-8')
    run(['-ss', 12.5, '-i', final, '-frames:v', 1, OUT / 'Steam视频封面-64秒.png'], 'poster.log')
    run(['-i', final, '-vf', 'fps=1/3,scale=480:270,tile=4x6', '-frames:v', 1, OUT / 'contact-sheet-64.jpg'], 'contact.log')
    run(['-i', final, '-map', '0:v:0', '-map', '0:a:0', '-f', 'null', '-'], 'decode-check.log')
    run(['-i', final, '-af', 'ebur128=peak=true', '-vn', '-f', 'null', '-'], 'loudness-check.log')
    print(str(final), flush=True)


if __name__ == '__main__':
    main()
