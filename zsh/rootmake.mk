# Some binaries
rclone       =rclone sync -LP --checkers 32 --transfers 64
pgctl        =/usr/local/bin/pg_ctl
pip          =pip-3.6
pip_opts     =--global-option=build_ext --global-option="-I/usr/local/include/" --global-option="-L/usr/local/lib"
psql         =/usr/local/bin/psql

# Things run out of here
rundir       =/usr/home/${USER}/run

# Database variables
pg_ver       =11
pg_rundir    =${rundir}/db/pg${pg_ver}
pg_snapname  =${db}-`date +"%Y-%m-%d-%H:%M:%S"`
pg_zfsds     =zroot/db/${USER}-${pg_ver}-dev

pgcfgadd:
.if exists(${pg_rundir}/PG_VERSION)
	cp ${cfg} ${pg_rundir}
.endif

pgsnap:
.if defined(db)
	-@${psql} -d ${db} -c "select pg_start_backup('${pg_snapname}', true);"
	-@sudo zfs snapshot ${pg_zfsds}@${pg_snapname}
	-@${psql} -d ${db} -c 'select pg_stop_backup();'
	-@sudo zfs list -rt snapshot | tail -1
.endif

pgstart: pgstop
.if exists(${pg_rundir}/PG_VERSION)
	-sudo zfs umount -f ${pg_zfsds}
	sudo zfs mount ${pg_zfsds}
	@${pgctl} -D ${pg_rundir} -l /tmp/logfile start
	@sh -c 'cd ${pg_rundir} && pgbouncer ${pg_rundir}/pg_bouncer.ini --daemon'
.endif

pgstop: pgsnap
	-pkill pgbouncer
	-@${pgctl} -D ${pg_rundir} stop

# Welcome! Let's get this machine ready for work. We'll wipe out
# previous traces of your environment, and reinitialize them by pulling
# a fresh copy from OneDrive and bootstrapping your dev environment.
ready: killenv
	-(export PAGER=/bin/cat \
		&& /usr/local/bin/sudo freebsd-update upgrade -r 12.0-RELEASE --not-running-from-cron\
		&& /usr/local/bin/sudo freebsd-update fetch install --not-running-from-cron)

	(export ASSUME_ALWAYS_YES=yes\
		&& sudo pkg install\
			git\
			libargon2\
			libxml2\
			libxslt\
			nginx\
			openssl\
			pgbouncer\
			postgresql11-server\
			python3-3_3\
			python36\
			python3\
			py36-pip\
			rclone)

	(make devenv-bootstrap-python)
	(make devenv-bootstrap-postgres)

	(make pull)

	(make startenv)

# Bye! We're done with this machine, so kill the environment and
# push all work to OneDrive
finish: killenv
	(make push)

# Push local files to remote. Alter the push set as you see fit, but
# make sure to maintain equivalence between this set and the one in the
# "pull" target.
push:
	${rclone} ./Makefile              onedrive:
	${rclone} ./.config               onedrive:.config
	${rclone} ./.devpi                onedrive:.devpi
	${rclone} ./.frieze               onedrive:.frieze
	${rclone} ./.gitconfig            onedrive:
	${rclone} ./.ssh                  onedrive:.ssh
	${rclone} ./.zsh_include          onedrive:.zsh_include
	${rclone} ./.zshrc                onedrive:
	${rclone} ./src                   onedrive:src

# Pull remote files from remote
pull:
	${rclone}  onedrive:Makefile      ./
	${rclone}  onedrive:.config       ./.config
	${rclone}  onedrive:.devpi        ./.devpi
	${rclone}  onedrive:.frieze       ./.frieze
	${rclone}  onedrive:.gitconfig    ./
	${rclone}  onedrive:.ssh          ./.ssh
	${rclone}  onedrive:.zsh_include  ./.zsh_include
	${rclone}  onedrive:.zshrc        ./
	${rclone}  onedrive:src           ./src

# Reset python environment by blowing out:
# - site packages
# - pip caches
# - the existing pip config
# Don't worry, it'll all come back later on.
killenv:
	-pkill python
	rm -rf ./.local/lib/python*
	rm -rf ./.local/bin/*
	rm -rf ./.cache/pip

startenv:
	-devpi-server --stop
	devpi-server --start
	devpi-server --status
	devpi login distuser --password=123

	(make pgstart)

devenv-bootstrap-python:
	-mv .config/pip/pip.conf .config/pip/pip.conf.tmp

	# Tox misbehaves, install it without options. We also need wheel, so
	# go ahead and install that too.
	${pip} install tox wheel --user
	${pip} install ${pip_opts} devpi-server devpi-client --user

	-mv .config/pip/pip.conf.tmp .config/pip/pip.conf

devenv-boostrap-postgres: pgstop
.if !exists(${pg_rundir}/PG_VERSION)
	@rm -rf /tmp/.s.PGSQL*
	@rm -rf ${pg_rundir}/*
	-@/bin/mkdir -p ${pg_rundir}
	-sudo zfs create -p -o mountpoint=${pg_rundir} ${pg_zfsds}
	-sudo zfs get atime,compression,primarycache,recordsize ${pg_zfsds}
	-sudo zfs set compression=lz4 ${pg_zfsds}
	-sudo zfs set atime=off ${pg_zfsds}
	-sudo zfs set recordsize=16K ${pg_zfsds}
	-sudo zfs set primarycache=metadata ${pg_zfsds}
	-sudo zfs get atime,compression,primarycache,recordsize ${pg_zfsds}
	sudo chown -R ${USER}:${USER} ${pg_rundir}
	initdb  --no-locale -E=UTF8 -n -N -D ${pg_rundir}
	(make pgstart)
.endif
