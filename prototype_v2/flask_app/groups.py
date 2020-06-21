import functools

from flask import (
    Blueprint, flash, g, redirect, render_template, request, session, url_for, abort
)
from werkzeug.security import check_password_hash, generate_password_hash
from flask_login import current_user

from flask_app.db import get_db
from flask_app.cache import cache
from flask_app.forms import LoginForm, SearchForm, GroupMessageForm, EditGroupMessageForm

bp = Blueprint('groups', __name__)


@bp.route('/local')
def local():
    flash('test message!')
    flash('an error occured!', category='failure')
    return render_template('base.html')


@bp.route('/')
def index():
    # if session.get('student_id') is None:
    if not current_user.is_authenticated:
        return redirect('/login')

    recent_messages = get_related_group_messages(current_user.id)
    groups = get_my_groups(current_user.id)

    return render_template('index.html', Groups_len=len(groups), Groups=groups, Messages_len=len(recent_messages), Messages=recent_messages)






@bp.route('/group/<int:group_id>/message', methods=('POST',))
def group_message(group_id):
    form = GroupMessageForm()
    if form.validate_on_submit():
        insert_group_message(group_id, current_user.id, form.message.data)
        flash('Deine Nachricht wurde erfolgreich abgesendet.', category='success')
        return redirect(url_for('groups.group', group_id=group_id))
    abort(500) # this shouldn't happen during normal operation.


def insert_group_message(group_id, student_id, message):
    db = get_db()

    with db.cursor() as cursor:
        cursor.callproc('GruppenBeitragVerfassen',
            [ 'USER', message, group_id, student_id ])

    db.commit()
    cache.delete_memoized(get_messages, group_id)




@bp.route('/group/<int:group_id>/message/<int:message_id>/edit', methods=('POST',))
def edit_group_message(group_id, message_id):
    form = EditGroupMessageForm()
    if form.validate_on_submit():
        message = get_cached_message(group_id, message_id)
        if not message or message['STUDENT_ID'] != current_user.id:
            raise Exception('This message cannot be edited.')

        if update_group_message(group_id, message_id, form.message.data):
            flash('Die Nachricht wurde erfolgreich bearbeitet.', category='success')
        else:
            flash('Ein Fehler ist aufgetreten.', category='failure')
        return redirect(url_for('groups.group', group_id=group_id))
    abort(500) # this shouldn't happen during normal operation.


def update_group_message(group_id, message_id, message):
    db = get_db()

    with db.cursor() as cursor:
        cursor.execute("""
            UPDATE GruppenBeitrag
            SET nachricht = :nachricht
            WHERE id = :beitrag_id
        """, beitrag_id=message_id, nachricht=message)

        if cursor.rowcount == 0:
            return False

    db.commit()
    cache.delete_memoized(get_messages, group_id)
    return True




@bp.route('/group/<int:group_id>/message/<int:message_id>/delete', methods=('POST',))
def remove_group_message(group_id, message_id):
    message = get_cached_message(group_id, message_id)
    if not message or message['STUDENT_ID'] != current_user.id:
        raise Exception('This message cannot be deleted.')

    if delete_group_message(group_id, message_id):
        flash('Die Nachricht wurde gelöscht.', category='success')
    else:
        flash('Ein Fehler ist aufgetreten.', category='failure')
    return redirect(url_for('groups.group', group_id=group_id))


def delete_group_message(group_id, message_id):
    db = get_db()

    with db.cursor() as cursor:
        cursor.execute("""
            DELETE FROM GruppenBeitrag
            WHERE id = :beitrag_id
        """, beitrag_id=message_id)

        if cursor.rowcount == 0:
            return False

    db.commit()
    cache.delete_memoized(get_messages, group_id)
    return True





@bp.route('/group/<int:group_id>')
def group(group_id):
    group = get_group(group_id) or abort(404)
    members = get_members(group_id)
    messages = get_messages(group_id)

    is_admin = group['ERSTELLER_ID'] == current_user.id
    is_member = False
    for member in members:
        if member['ID'] == current_user.id:
            is_member = True
            break

    message_form = GroupMessageForm()

    return render_template('group.html',
        group_id=group_id, group=group, members=members, messages=messages,
        message_form=message_form, EditGroupMessageForm=EditGroupMessageForm,
        is_admin=is_admin, is_member=is_member)


@bp.route('/search')
def search():
    form = SearchForm()
    form.module_id.choices = [(-1, 'Alle Module')] + get_all_modules()

    module = request.args.get('module_id', '-1')
    q = request.args.get('q', '')
    free = request.args.get('free', '1')

    form.module_id.default = module
    form.process()
    form.q.data = q
    form.free.data = free

    groups = get_groups(module, q, free)

    return render_template('search.html', title='Suche', form=form, len=len(groups), Groups=groups)

@cache.cached(timeout=60*60)
def get_all_modules():
    db = get_db()

    with db.cursor() as cursor:
        cursor.execute("""
            SELECT id, name
            FROM Modul
        """)
        return [ (mid, name) for mid, name in cursor ]

@cache.memoize(timeout=60)
def get_related_group_messages(student_id):
    db = get_db()

    with db.cursor() as cursor:

        cursor.execute("""
                SELECT  id,
                        gruppe_id,
                        (SELECT name FROM Gruppe WHERE id = gruppe_id) gruppe,
                        (SELECT name FROM Modul WHERE id = (SELECT modul_id FROM Gruppe WHERE id = gruppe_id)) modul,
                        student_id as ersteller_id,
                        (SELECT name FROM Student WHERE id = gb.student_id) ersteller,
                        nachricht,
                        datum,
                        typ
                FROM GruppenBeitrag gb
                WHERE gruppe_id IN (SELECT gruppe_id FROM Gruppe_Student WHERE student_id = :student)
                ORDER BY datum DESC
                FETCH NEXT 5 ROWS ONLY
            """, student = student_id) # student = session.get('student_id'))

        cursor.rowfactory = lambda *args: dict(zip([d[0] for d in cursor.description], args))
        return cursor.fetchall()

# TODO: invalidate cache when entering a group.
@cache.memoize(timeout=60*10)
def get_my_groups(student_id):
    db = get_db()

    with db.cursor() as cursor:

        cursor.execute("""
                SELECT  id,
                        modul_id,
                        (SELECT name FROM Modul WHERE modul_id = Modul.id) modul,
                        g.name,
                        (SELECT count(ersteller_id) FROM Gruppe WHERE id = g.id AND ersteller_id = :student) ist_ersteller,
                        (SELECT count(student_id) FROM Gruppe_Student WHERE gruppe_id = g.id AND student_id = :student) ist_mitglied,
                        (SELECT count(student_id) FROM Gruppe_Student WHERE gruppe_id = g.id) mitglieder,
                        g.limit,
                        oeffentlich,
                        betretbar,
                        deadline,
                        ort
                FROM Gruppe g
                WHERE :student IN (SELECT student_id FROM Gruppe_Student WHERE gruppe_id = g.id)
                ORDER BY ist_mitglied, deadline DESC
            """, student = student_id) # session.get('student_id'))

        cursor.rowfactory = lambda *args: dict(zip([d[0] for d in cursor.description], args))
        return cursor.fetchall()

@cache.memoize(timeout=60*10)
def get_groups(module, description, free):
    db = get_db()

    with db.cursor() as cursor:

        cursor.execute("""
                SELECT  id,
                        modul_id,
                        (SELECT name FROM Modul WHERE modul_id = Modul.id) modul,
                        g.name,
                        (SELECT count(ersteller_id) FROM Gruppe WHERE id = g.id AND ersteller_id = :student) ist_ersteller,
                        (SELECT count(student_id) FROM Gruppe_Student WHERE gruppe_id = g.id AND student_id = :student) ist_mitglied,
                        (SELECT count(student_id) FROM Gruppe_Student WHERE gruppe_id = g.id) mitglieder,
                        g.limit,
                        oeffentlich,
                        betretbar,
                        deadline,
                        ort
                FROM Gruppe g
                WHERE   (:modul = -1 OR modul_id = :modul) AND
                        (g.name LIKE :bezeichnung OR ort LIKE :bezeichnung) AND
                        (g.limit IS NULL OR g.limit - (SELECT count(student_id) FROM Gruppe_Student WHERE gruppe_id = g.id) >= :freie)
                ORDER BY ist_mitglied, deadline DESC
            """, student = current_user.id, # session.get('student_id'),
                 modul = module,
                 bezeichnung = "%" + description + "%",
                 freie = free)

        cursor.rowfactory = lambda *args: dict(zip([d[0] for d in cursor.description], args))
        return cursor.fetchall()


@cache.memoize(timeout=60*1)
def get_group(group_id):
    db = get_db()

    with db.cursor() as cursor:

        cursor.execute("""
            SELECT  id,
                    ersteller_id,
                    modul_id,
                    (SELECT name FROM Modul WHERE modul_id = Modul.id) modul,
                    g.name,
                    g.limit,
                    oeffentlich,
                    betretbar,
                    deadline,
                    ort
            FROM Gruppe g
            WHERE g.id = :gruppe_id
        """, gruppe_id = group_id)

        cursor.rowfactory = lambda *args: dict(zip([d[0] for d in cursor.description], args))
        return cursor.fetchone()


@cache.memoize(timeout=60*1)
def get_members(group_id):
    db = get_db()

    with db.cursor() as cursor:

        cursor.execute("""
            SELECT s.id, s.name
            FROM Gruppe_Student gs
            INNER JOIN Student s ON gs.student_id = s.id
            WHERE gs.gruppe_id = :gruppe_id
        """, gruppe_id = group_id)

        cursor.rowfactory = lambda *args: dict(zip([d[0] for d in cursor.description], args))
        return cursor.fetchall()


@cache.memoize(timeout=60*1)
def get_messages(group_id):
    db = get_db()

    with db.cursor() as cursor:

        cursor.execute("""
            SELECT gb.id, gb.student_id, s.name as student, gb.datum, gb.nachricht, gb.typ
            FROM GruppenBeitrag gb
            LEFT JOIN Student s ON gb.student_id = s.id
            WHERE gb.gruppe_id = :gruppe_id
            ORDER BY gb.datum ASC
        """, gruppe_id = group_id)

        cursor.rowfactory = lambda *args: dict(zip([d[0] for d in cursor.description], args))
        return cursor.fetchall()


# get_messages will always be called before this function.
# thus a call to get_messages will land a cache hit and be really fast.
def get_cached_message(group_id, message_id):
    print(get_messages(group_id))
    for message in get_messages(group_id):
        if message['ID'] == message_id:
            return message
    return None
