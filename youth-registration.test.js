const assert=require('node:assert/strict'),y=require('./youth-common.js');
for(const [birth,on,expected] of [['2008-10-17','2026-10-17',18],['2008-10-18','2026-10-17',17],['2013-10-17','2026-10-17',13],['2027-01-01','2026-10-17',null],['2012-02-30','2026-10-17',null],['2012-02-29','2026-02-28',13],['2012-02-29','2026-03-01',14],['','2026-10-17',null]])assert.equal(y.age(birth,on),expected);
assert.match(y.today(),/^\d{4}-\d{2}-\d{2}$/);
console.log('Youth age boundary tests passed.');
