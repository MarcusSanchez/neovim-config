pub fn foobar() -> i32 { 1 }

pub fn f_o_o_b_a_r_x() -> i32 { 2 }

pub fn caller() -> i32 { foobar() }

#[test]
fn foobar_bare_test() { assert_eq!(foobar(), 1); }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn foobar_in_mod() {
        assert_eq!(foobar(), 1);
    }
}
