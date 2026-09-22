"""Rebuild the approved 60-second Chinese Steam trailer from isolated Godot captures."""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/steam-trailer-zh'
WORK = OUT / 'work'
FFMPEG = ROOT / '.tmp/tianjin-living/python/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
FONT = 'resource/fonts/KNMaiyuan/KNMaiyuan-Regular.ttf'


def run(args, log):
    with (WORK / log).open('w', encoding='utf-8') as stream:
        result = subprocess.run([str(FFMPEG), '-hide_banner', '-y', *map(str, args)], cwd=ROOT,
                                stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError((WORK / log).read_text(encoding='utf-8')[-5000:])


def text_file(name, text):
    path = WORK / (name + '.txt')
    path.write_text(text, encoding='utf-8')
    return path.relative_to(ROOT).as_posix()


def draw(name, text, size, x, y, color='FFF8E9', more=''):
    path = text_file(name, text)
    return f"drawtext=fontfile='{FONT}':textfile='{path}':fontsize={size}:fontcolor=0x{color}:x={x}:y={y}" + more


def marker(shot, name, occurrence=0):
    lines = (WORK / f'{shot}-marks.tsv').read_text(encoding='utf-8-sig').splitlines()
    return [float(line.split('\t')[0]) for line in lines if line.split('\t')[1] == name][occurrence]


def main():
    # Times align to 30-fps boundaries. No synthetic gameplay, frame interpolation, or speed changes.
    cuts = [
        ('tianjin', 'batter', 0, 4.0),
        ('tianjin', 'flip', 0, 0.8),
        ('tianjin', 'sauce', 0, 3.3),
        ('tianjin', 'fold', 0, 2.4),
        ('tianjin', 'stored_youtiao', 0, 3.5),
        ('rush', 'fryer-load', 0, 4.0),
        ('rush', 'fold', 0, 5.0),
        ('rush', 'spread', 1, 3.0),
        ('wuhan', 'noodles-drop', 0, 6.5),
        ('wuhan', 'mix', 1, 3.5),
        ('wuhan', 'doupi-egg', 0, 3.5),
        ('wuhan', 'doupi-cut', 0, 3.0),
        ('pages', 'upgrade', 0, 7.0),
        ('rush', 'delivery', 1, 1.5),
        ('wuhan', 'doupi-delivery', 0, 2.0),
    ]
    manifest, files = [], []
    timeline = 0.0
    for i, (shot, mark, occurrence, duration) in enumerate(cuts):
        start = round(marker(shot, mark, occurrence) * 30) / 30
        target = WORK / f'cut-{i:02d}.mp4'
        # The menu capture contains its own music, so use silence there under the continuous trailer bed.
        audio = 'volume=0' if shot == 'pages' else 'volume=1'
        source = WORK / f'{shot}.avi'
        signature = json.dumps([source.name, source.stat().st_mtime_ns, start, duration, audio, 'bt709-limited-v1'])
        cache = target.with_suffix('.cache')
        if not target.exists() or not cache.exists() or cache.read_text() != signature:
            run(['-ss', start, '-i', source, '-t', duration,
             '-vf', 'scale=in_range=pc:out_range=tv,format=yuv420p,setsar=1,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709', '-af', f'{audio},afade=t=in:d=0.025,afade=t=out:st={duration-.04}:d=0.04',
             '-r', 30, '-c:v', 'libx264', '-preset', 'fast', '-crf', 17,
             '-color_range', 'tv', '-c:a', 'aac', '-b:a', '256k', '-ar', 48000, '-ac', 2, target], f'encode-{i:02d}.log')
            cache.write_text(signature)
        manifest.append(dict(start=round(timeline, 3), duration=duration, source=f'{shot}.avi', source_start=start, action=mark))
        timeline += duration
        files.append(target)
        print(f'CUT {i+1}/{len(cuts)} {shot} {mark}', flush=True)

    assert abs(timeline - 53) < .001, timeline
    background = ROOT / 'resource/art/Global/StartPage/开始页面早餐铺背景.png'
    logo = ROOT / 'resource/art/Global/StartPage/全世界等我开饭.png'
    end = WORK / 'end.mp4'
    end_filters = [
        '[0:v]scale=1920:1080,setsar=1[bg]',
        '[1:v]scale=1100:-1[logo]',
        '[bg][logo]overlay=(W-w)/2:125[brand]',
        '[brand]' + ','.join([
            'drawbox=x=570:y=705:w=780:h=170:color=0xFFF5DF@0.94:t=fill',
            draw('end-cta', 'Steam · 加入愿望单', 60, '(w-tw)/2', 730, '57371F'),
            draw('end-demo', '天津 × 武汉  /  双城 Demo', 36, '(w-tw)/2', 820, '6F4B31'),
            'drawbox=x=0:y=956:w=iw:h=124:color=0xFFF5DF@0.92:t=fill',
            draw('credit1', '音乐：Carefree — Kevin MacLeod (incompetech.com)', 22, '(w-tw)/2', 974, '57371F'),
            draw('credit2', 'CC BY 4.0 · creativecommons.org/licenses/by/4.0/', 22, '(w-tw)/2', 1008, '57371F'),
            draw('credit3', '音乐改动：节选、音量调整与淡入淡出', 20, '(w-tw)/2', 1041, '57371F'),
            'fade=t=in:d=0.25', 'format=yuv420p', 'setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709',
        ]) + '[end]',
    ]
    run(['-loop', 1, '-framerate', 30, '-i', background, '-loop', 1, '-framerate', 30, '-i', logo,
         '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-filter_complex', ';'.join(end_filters),
         '-map', '[end]', '-map', '2:a', '-t', 7, '-c:v', 'libx264', '-preset', 'fast', '-crf', 17,
         '-c:a', 'aac', '-b:a', '256k', '-ar', 48000, '-ac', 2, end], 'end-encode.log')
    files.append(end)
    concat = WORK / 'concat.txt'
    concat.write_text('\n'.join("file '" + p.as_posix() + "'" for p in files), encoding='utf-8')
    run(['-f', 'concat', '-safe', 0, '-i', concat, '-c', 'copy', WORK / 'assembly.mp4'], 'assembly.log')

    captions = [
        (0.3, 4.4, '亲手做一份，热乎的早饭'),
        (7.8, 13.7, '摊煎饼、炸油条、配豆浆'),
        (18.1, 24.7, '早餐高峰，忙得刚刚好'),
        (26.2, 31.8, '下一站，武汉过早'),
        (36.1, 41.8, '热干面、三鲜豆皮，都安排上'),
        (42.7, 48.8, '把小铺子，一点点经营起来'),
    ]
    subtitles = []
    for i, (start, finish, text) in enumerate(captions):
        subtitles.append(draw(f'caption-{i}', text, 46, '(w-tw)/2', 995,
                              more=f":borderw=4:bordercolor=0x50311D:shadowcolor=0x50311D@0.45:shadowx=2:shadowy=3:enable='between(t,{start},{finish})'"))
    video_filter = 'format=yuv420p,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709,' + ','.join(subtitles)
    music = ROOT / 'resource/audio/demo/Carefree.mp3'
    filters = f"[0:v]{video_filter}[v];[0:a]volume=0.90[sfx];[1:a]atrim=duration=60,asetpts=PTS-STARTPTS,loudnorm=I=-21:LRA=9:TP=-3,afade=t=in:d=0.5,afade=t=out:st=57.5:d=2.5[music];[sfx][music]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:LRA=9:TP=-1.5[a]"
    final = OUT / '全世界等我开饭-Steam宣传片-中文-1080p.mp4'
    run(['-i', WORK / 'assembly.mp4', '-ss', 24, '-i', music, '-filter_complex', filters,
         '-map', '[v]', '-map', '[a]', '-t', 60, '-r', 30,
         '-c:v', 'libx264', '-preset', 'slow', '-b:v', '12M', '-minrate', '12M', '-maxrate', '12M', '-bufsize', '24M',
         '-x264-params', 'nal-hrd=cbr:filler=1',
         '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1',
         '-color_range', 'tv', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
         '-c:a', 'aac', '-b:a', '256k', '-ar', 48000, '-ac', 2, '-movflags', '+faststart', final], 'final-encode.log')
    (OUT / 'edit-timeline.json').write_text(json.dumps({'fps': 30, 'duration': 60, 'cuts': manifest, 'captions': captions,
        'end_card': {'start': 53, 'duration': 7}, 'music': {'file': 'Carefree.mp3', 'start': 24}}, ensure_ascii=False, indent=2), encoding='utf-8')
    run(['-ss', 25.4, '-i', final, '-frames:v', 1, OUT / 'Steam视频封面.png'], 'poster.log')
    run(['-i', final, '-vf', 'fps=1/5,scale=480:270,tile=4x3', '-frames:v', 1, OUT / 'contact-sheet.jpg'], 'contact.log')
    run(['-i', final, '-map', '0:v:0', '-map', '0:a:0', '-f', 'null', '-'], 'decode-check.log')
    run(['-i', final, '-af', 'volumedetect', '-vn', '-f', 'null', '-'], 'audio-check.log')
    run(['-i', final, '-af', 'ebur128=peak=true', '-vn', '-f', 'null', '-'], 'loudness-check.log')
    print(str(final), flush=True)


if __name__ == '__main__':
    main()
