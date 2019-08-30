# mount-img

small script to mount `.img` files

## Mount/umount a .img file

### Mount all partitions

To mount a `.img` file, execute

```sh
sudo mount-img.sh -m <img_files>
```

By default, the script will mount all partitions in /media/<img_file> folder. If the script can't get labels of partitions, they will be named partitionX, with X the number of the parttion.

For example, the following output :

```sh
$ sudo mount-img.sh -m image.img
$ tree -L 2 /media
/media
├── user
│   ├── folder
└── image.img
    ├── partition1
    ├── partition2
    └── partition3
```

### Umount all partitions

To umount a `.img` file, execute

```sh
sudo mount-img.sh -u <img_files>
```

## All options

| option   | description                            |
|----------|----------------------------------------|
| -m       | Mounting mode                          |
| -u       | Umounting mode                         |
| -i       | Information of the disk (mount or not) |
| -d <dir> | Directory to mount (default /media)    |
| -h       | Print help information                 |