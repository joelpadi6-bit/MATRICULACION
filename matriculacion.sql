--crear y usar la base de datos
create database if not exists matriculacion_universitaria;
use matriculacion_universitaria;

--tabla de estudiantes
create table estudiantes (
    estudiante_id int not null auto_increment,
    nombre varchar(120) not null,
    cedula varchar(20) not null,
    facultad varchar(120) not null,
    primary key (estudiante_id),
    unique key uq_estudiantes_cedula (cedula)
);

--tabla de asignaturas
create table asignaturas (
    asignatura_id int not null auto_increment,
    nombre_materia varchar(120) not null,
    docente varchar(120) not null,
    cupos_disponibles int not null,
    primary key (asignatura_id),
    constraint chk_asignaturas_cupos check (cupos_disponibles >= 0)
);

--tabla de registros de matricula
create table registros_matricula (
    registro_id int not null auto_increment,
    estudiante_id int not null,
    asignatura_id int not null,
    fecha_registro datetime not null default current_timestamp,
    estado enum('CONFIRMADA', 'PENDIENTE') not null default 'PENDIENTE',
    primary key (registro_id),
    constraint fk_matricula_estudiante foreign key (estudiante_id) references estudiantes (estudiante_id),
    constraint fk_matricula_asignatura foreign key (asignatura_id) references asignaturas (asignatura_id),
    constraint uq_matricula_estudiante_asignatura unique (estudiante_id, asignatura_id)
);

-- datos de prueba
insert into estudiantes (nombre, cedula, facultad) values 
('Aleyda Cruz', 'CED-1001', 'Ingenieria'),
('Andrea Guerrero', 'CED-1002', 'Ingenieria'),
('Joel Padilla', 'CED-1003', 'Ciencias');

insert into asignaturas (nombre_materia, docente, cupos_disponibles) values 
('Base de Datos', 'Dr. Rivera', 5),
('Programacion I', 'Mtra. Soto', 5),
('Redes', 'Ing. Torres', 5);

--transaccion a: uso de commit matricula exitosa

start transaction;

--descontar cupo
update asignaturas
set cupos_disponibles = cupos_disponibles - 1
where nombre_materia = 'Base de Datos'
  and cupos_disponibles > 0;

--insertar registro de matricula para aleyda cruz
insert into registros_matricula (estudiante_id, asignatura_id, estado)
select 
    1, 
    asignatura_id, 
    'CONFIRMADA'
from asignaturas
where nombre_materia = 'Base de Datos';
commit;

--verificacion
select * from registros_matricula;
select * from asignaturas where nombre_materia = 'Base de Datos';

--transaccion b: uso de rollback matricula cancelada

start transaction;

-- intentar insertar registro para andrea guerrero
insert into registros_matricula (estudiante_id, asignatura_id, estado)
select 
    2, 
    asignatura_id, 
    'PENDIENTE'
from asignaturas
where nombre_materia = 'Base de Datos';

--cancelar transaccion
rollback;

--verificacion
select * from registros_matricula;

-- transaccion c: matricula multimateria atomicidad

start transaction;

update asignaturas 
set cupos_disponibles = cupos_disponibles - 1 
where asignatura_id = 1 and cupos_disponibles > 0;

update asignaturas 
set cupos_disponibles = cupos_disponibles - 1 
where asignatura_id = 2 and cupos_disponibles > 0;

--simular error con id inexistente
update asignaturas 
set cupos_disponibles = cupos_disponibles - 1 
where asignatura_id = 9999;

rollback;

--verificacion
select asignatura_id, nombre_materia, cupos_disponibles 
from asignaturas 
where asignatura_id in (1, 2);


--control de bloqueos y niveles de aislamiento


--nivel: read committed
--sesion 1
set session transaction isolation level read committed;
start transaction;
update asignaturas set cupos_disponibles = cupos_disponibles - 1 where nombre_materia = 'Base de Datos' and cupos_disponibles > 0;

--sesion 2
set session transaction isolation level read committed;
start transaction;
select cupos_disponibles from asignaturas where nombre_materia = 'Base de Datos';
commit;

--finalizar sesion 1
rollback;

--nivel: repeatable read
--sesion 1
set session transaction isolation level repeatable read;
start transaction;
select cupos_disponibles from asignaturas where nombre_materia = 'Base de Datos';

--sesion 2
start transaction;
update asignaturas set cupos_disponibles = cupos_disponibles - 2 where nombre_materia = 'Base de Datos';
commit;

--verificacion sesion 1
select cupos_disponibles from asignaturas where nombre_materia = 'Base de Datos';
commit;