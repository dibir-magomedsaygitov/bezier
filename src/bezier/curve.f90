! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!     https://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
! limitations under the License.

module curve

  use iso_c_binding, only: c_double, c_int, c_bool
  use types, only: dp
  use helpers, only: contains_nd
  implicit none
  private LocateCandidate, MAX_LOCATE_SUBDIVISIONS, LOCATE_STD_CAP
  public &
       evaluate_curve_barycentric, evaluate_multi, specialize_curve_generic, &
       specialize_curve_quadratic, specialize_curve, evaluate_hodograph, &
       subdivide_nodes_generic, subdivide_nodes, newton_refine, locate_point

  ! For ``locate_point``.
  type :: LocateCandidate
     real(c_double) :: start
     real(c_double) :: end_
     real(c_double), allocatable :: nodes(:, :)
  end type LocateCandidate

  ! NOTE: These values are also defined in `src/bezier/_curve_helpers.py`.
  integer(c_int), parameter :: MAX_LOCATE_SUBDIVISIONS = 20
  real(c_double), parameter :: LOCATE_STD_CAP = 0.5_dp**20

contains

  subroutine evaluate_curve_barycentric( &
       degree, dimension_, nodes, num_vals, lambda1, lambda2, evaluated) &
       bind(c, name='evaluate_curve_barycentric')

    ! NOTE: This is evaluate_multi_barycentric for a Bezier curve.

    integer(c_int), intent(in) :: degree, dimension_
    real(c_double), intent(in) :: nodes(degree + 1, dimension_)
    integer(c_int), intent(in) :: num_vals
    real(c_double), intent(in) :: lambda1(num_vals)
    real(c_double), intent(in) :: lambda2(num_vals)
    real(c_double), intent(out) :: evaluated(num_vals, dimension_)
    ! Variables outside of signature.
    integer(c_int) :: i, j
    real(c_double) :: lambda2_pow(num_vals)
    integer(c_int) :: binom_val

    lambda2_pow = 1.0_dp
    binom_val = 1

    forall (i = 1:num_vals)
       evaluated(i, :) = lambda1(i) * nodes(1, :)
    end forall

    do i = 2, degree
       lambda2_pow = lambda2_pow * lambda2
       binom_val = (binom_val * (degree - i + 2)) / (i - 1)
       forall (j = 1:num_vals)
          evaluated(j, :) = ( &
               evaluated(j, :) + &
               binom_val * lambda2_pow(j) * nodes(i, :)) * lambda1(j)
       end forall
    end do

    forall (i = 1:num_vals)
       evaluated(i, :) = ( &
            evaluated(i, :) + &
            lambda2_pow(i) * lambda2(i) * nodes(degree + 1, :))
    end forall

  end subroutine evaluate_curve_barycentric

  subroutine evaluate_multi( &
       degree, dimension_, nodes, num_vals, s_vals, evaluated) &
       bind(c, name='evaluate_multi')

    ! NOTE: This is evaluate_multi for a Bezier curve.

    integer(c_int), intent(in) :: degree, dimension_
    real(c_double), intent(in) :: nodes(degree + 1, dimension_)
    integer(c_int), intent(in) :: num_vals
    real(c_double), intent(in) :: s_vals(num_vals)
    real(c_double), intent(out) :: evaluated(num_vals, dimension_)
    ! Variables outside of signature.
    real(c_double) :: one_less(num_vals)

    one_less = 1.0_dp - s_vals
    call evaluate_curve_barycentric( &
         degree, dimension_, nodes, num_vals, one_less, s_vals, evaluated)
  end subroutine evaluate_multi

  subroutine specialize_curve_generic( &
       degree, dimension_, nodes, start, end_, new_nodes) &
       bind(c, name='specialize_curve_generic')

    ! NOTE: This is a helper for ``specialize_curve`` that works on any degree.

    integer(c_int), intent(in) :: degree, dimension_
    real(c_double), intent(in) :: nodes(degree + 1, dimension_)
    real(c_double), intent(in) :: start, end_
    real(c_double), intent(out) :: new_nodes(degree + 1, dimension_)
    ! Variables outside of signature.
    real(c_double) :: workspace(degree, dimension_, degree + 1)
    integer(c_int) :: index_, curr_size, j
    real(c_double) :: minus_start, minus_end

    minus_start = 1.0_dp - start
    minus_end = 1.0_dp - end_
    workspace(:, :, 1) = minus_start * nodes(:degree, :) + start * nodes(2:, :)
    workspace(:, :, 2) = minus_end * nodes(:degree, :) + end_ * nodes(2:, :)

    curr_size = degree
    do index_ = 3, degree + 1
       curr_size = curr_size - 1
       ! First add a new "column" (or whatever the 3rd dimension is called)
       ! at the end using ``end_``.
       workspace(:curr_size, :, index_) = ( &
            minus_end * workspace(:curr_size, :, index_ - 1) + &
            end_ * workspace(2:curr_size + 1, :, index_ - 1))
       ! Update all the values in place by using de Casteljau with the
       ! ``start`` parameter.
       forall (j = 1:index_ - 1)
          workspace(:curr_size, :, j) = ( &
               minus_start * workspace(:curr_size, :, j) + &
               start * workspace(2:curr_size + 1, :, j))
       end forall
    end do

    ! Move the final "column" (or whatever the 3rd dimension is called)
    ! of the workspace into ``new_nodes``.
    forall (index_ = 1:degree + 1)
       new_nodes(index_, :) = workspace(1, :, index_)
    end forall

  end subroutine specialize_curve_generic

  subroutine specialize_curve_quadratic( &
       dimension_, nodes, start, end_, new_nodes) &
       bind(c, name='specialize_curve_quadratic')

    integer(c_int), intent(in) :: dimension_
    real(c_double), intent(in) :: nodes(3, dimension_)
    real(c_double), intent(in) :: start, end_
    real(c_double), intent(out) :: new_nodes(3, dimension_)
    ! Variables outside of signature.
    real(c_double) :: minus_start, minus_end, prod_both

    minus_start = 1.0_dp - start
    minus_end = 1.0_dp - end_
    prod_both = start * end_

    new_nodes(1, :) = ( &
         minus_start * minus_start * nodes(1, :) + &
         2.0_dp * start * minus_start * nodes(2, :) + &
         start * start * nodes(3, :))
    new_nodes(2, :) = ( &
         minus_start * minus_end * nodes(1, :) + &
         (end_ + start - 2.0_dp * prod_both) * nodes(2, :) + &
         prod_both * nodes(3, :))
    new_nodes(3, :) = ( &
         minus_end * minus_end * nodes(1, :) + &
         2.0_dp * end_ * minus_end * nodes(2, :) + &
         end_ * end_ * nodes(3, :))

  end subroutine specialize_curve_quadratic

  subroutine specialize_curve( &
       degree, dimension_, nodes, start, end_, curve_start, curve_end, &
       new_nodes, true_start, true_end) &
       bind(c, name='specialize_curve')

    integer(c_int), intent(in) :: degree, dimension_
    real(c_double), intent(in) :: nodes(degree + 1, dimension_)
    real(c_double), intent(in) :: start, end_, curve_start, curve_end
    real(c_double), intent(out) :: new_nodes(degree + 1, dimension_)
    real(c_double), intent(out) :: true_start, true_end
    ! Variables outside of signature.
    real(c_double) :: interval_delta

    if (degree == 1) then
       new_nodes(1, :) = (1.0_dp - start) * nodes(1, :) + start * nodes(2, :)
       new_nodes(2, :) = (1.0_dp - end_) * nodes(1, :) + end_ * nodes(2, :)
    else if (degree == 2) then
       call specialize_curve_quadratic( &
            dimension_, nodes, start, end_, new_nodes)
    else
       call specialize_curve_generic( &
            degree, dimension_, nodes, start, end_, new_nodes)
    end if

    ! Now, compute the new interval.
    interval_delta = curve_end - curve_start
    true_start = curve_start + start * interval_delta
    true_end = curve_start + end_ * interval_delta

  end subroutine specialize_curve

  subroutine evaluate_hodograph( &
       s, degree, dimension_, nodes, hodograph) &
       bind(c, name='evaluate_hodograph')

    real(c_double), intent(in) :: s
    integer(c_int), intent(in) :: degree, dimension_
    real(c_double), intent(in) :: nodes(degree + 1, dimension_)
    real(c_double), intent(out) :: hodograph(1, dimension_)
    ! Variables outside of signature.
    real(c_double) :: first_deriv(degree, dimension_)
    real(c_double) :: param(1)

    first_deriv = nodes(2:, :) - nodes(:degree, :)
    param = s
    call evaluate_multi( &
         degree - 1, dimension_, first_deriv, 1, param, hodograph)
    hodograph = degree * hodograph

  end subroutine evaluate_hodograph

  subroutine subdivide_nodes_generic( &
       num_nodes, dimension_, nodes, left_nodes, right_nodes) &
       bind(c, name='subdivide_nodes_generic')

    integer(c_int), intent(in) :: num_nodes, dimension_
    real(c_double), intent(in) :: nodes(num_nodes, dimension_)
    real(c_double), intent(out) :: left_nodes(num_nodes, dimension_)
    real(c_double), intent(out) :: right_nodes(num_nodes, dimension_)
    ! Variables outside of signature.
    real(c_double) :: pascals_triangle(num_nodes)
    integer(c_int) :: elt_index, pascal_index

    pascals_triangle = 0  ! Make sure all zero.
    pascals_triangle(1) = 1

    do elt_index = 1, num_nodes
       ! Update Pascal's triangle (intentionally at beginning, not end).
       if (elt_index > 1) then
          pascals_triangle(:elt_index) = 0.5_dp * ( &
               pascals_triangle(:elt_index) + pascals_triangle(elt_index:1:-1))
       end if

       left_nodes(elt_index, :) = 0
       right_nodes(num_nodes + 1 - elt_index, :) = 0
       do pascal_index = 1, elt_index
          left_nodes(elt_index, :) = ( &
               left_nodes(elt_index, :) + &
               pascals_triangle(pascal_index) * nodes(pascal_index, :))
          right_nodes(num_nodes + 1 - elt_index, :) = ( &
               right_nodes(num_nodes + 1 - elt_index, :) + &
               pascals_triangle(pascal_index) * &
               nodes(num_nodes + 1 - pascal_index, :))
       end do
    end do

  end subroutine subdivide_nodes_generic

  subroutine subdivide_nodes( &
       num_nodes, dimension_, nodes, left_nodes, right_nodes) &
       bind(c, name='subdivide_nodes')

    integer(c_int), intent(in) :: num_nodes, dimension_
    real(c_double), intent(in) :: nodes(num_nodes, dimension_)
    real(c_double), intent(out) :: left_nodes(num_nodes, dimension_)
    real(c_double), intent(out) :: right_nodes(num_nodes, dimension_)

    if (num_nodes == 2) then
       left_nodes(1, :) = nodes(1, :)
       left_nodes(2, :) = 0.5_dp * (nodes(1, :) + nodes(2, :))
       right_nodes(1, :) = left_nodes(2, :)
       right_nodes(2, :) = nodes(2, :)
    else if (num_nodes == 3) then
       left_nodes(1, :) = nodes(1, :)
       left_nodes(2, :) = 0.5_dp * (nodes(1, :) + nodes(2, :))
       left_nodes(3, :) = 0.25_dp * ( &
            nodes(1, :) + 2 * nodes(2, :) + nodes(3, :))
       right_nodes(1, :) = left_nodes(3, :)
       right_nodes(2, :) = 0.5_dp * (nodes(2, :) + nodes(3, :))
       right_nodes(3, :) = nodes(3, :)
    else if (num_nodes == 4) then
       left_nodes(1, :) = nodes(1, :)
       left_nodes(2, :) = 0.5_dp * (nodes(1, :) + nodes(2, :))
       left_nodes(3, :) = 0.25_dp * ( &
            nodes(1, :) + 2 * nodes(2, :) + nodes(3, :))
       left_nodes(4, :) = 0.125_dp * ( &
            nodes(1, :) + 3 * nodes(2, :) + 3 * nodes(3, :) + nodes(4, :))
       right_nodes(1, :) = left_nodes(4, :)
       right_nodes(2, :) = 0.25_dp * ( &
            nodes(2, :) + 2 * nodes(3, :) + nodes(4, :))
       right_nodes(3, :) = 0.5_dp * (nodes(3, :) + nodes(4, :))
       right_nodes(4, :) = nodes(4, :)
    else
       call subdivide_nodes_generic( &
            num_nodes, dimension_, nodes, left_nodes, right_nodes)
    end if

  end subroutine subdivide_nodes

  subroutine newton_refine( &
       num_nodes, dimension_, nodes, point, s, updated_s) &
       bind(c, name='newton_refine')

    integer(c_int), intent(in) :: num_nodes, dimension_
    real(c_double), intent(in) :: nodes(num_nodes, dimension_)
    real(c_double), intent(in) :: point(1, dimension_)
    real(c_double), intent(in) :: s
    real(c_double), intent(out) :: updated_s
    ! Variables outside of signature.
    real(c_double) :: pt_delta(1, dimension_)
    real(c_double) :: derivative(1, dimension_)

    call evaluate_multi( &
         num_nodes - 1, dimension_, nodes, 1, [s], pt_delta)
    pt_delta = point - pt_delta
    ! At this point `pt_delta` is `p - B(s)`.
    call evaluate_hodograph( &
         s, num_nodes - 1, dimension_, nodes, derivative)

    updated_s = ( &
         s + &
         (dot_product(pt_delta(1, :), derivative(1, :)) / &
         dot_product(derivative(1, :), derivative(1, :))))

  end subroutine newton_refine

  subroutine locate_point( &
       num_nodes, dimension_, nodes, point, s_approx) &
       bind(c, name='locate_point')

    ! NOTE: This returns ``-1`` as a signal for "point is not on the curve"
    !       and ``-2`` for "point is on separate segments" (i.e. the
    !       standard deviation of the parameters is too large)

    integer(c_int), intent(in) :: num_nodes, dimension_
    real(c_double), intent(in) :: nodes(num_nodes, dimension_)
    real(c_double), intent(in) :: point(1, dimension_)
    real(c_double), intent(out) :: s_approx
    ! Variables outside of signature.
    type(LocateCandidate), allocatable :: candidates(:), next_candidates(:)
    integer(c_int) :: sub_index, cand_index
    integer(c_int) :: num_candidates, num_next_candidates
    type(LocateCandidate) :: candidate
    real(c_double), allocatable :: s_params(:)
    real(c_double) :: midpoint, std_dev
    logical(c_bool) :: predicate

    ! Start out with the full curve.
    allocate(candidates(1))
    candidates(1) = LocateCandidate(0.0_dp, 1.0_dp, nodes)
    ! NOTE: `num_candidates` will be tracked separately
    !       from `size(candidates)`.
    num_candidates = 1
    s_approx = -1.0_dp

    do sub_index = 1, MAX_LOCATE_SUBDIVISIONS + 1
       num_next_candidates = 0
       ! Allocate maximum amount of space needed.
       allocate(next_candidates(2 * num_candidates))
       do cand_index = 1, num_candidates
          candidate = candidates(cand_index)
          call contains_nd( &
               num_nodes, dimension_, candidate%nodes, point(1, :), predicate)
          if (predicate) then
             num_next_candidates = num_next_candidates + 2

             midpoint = 0.5_dp * (candidate%start + candidate%end_)

             ! Left half.
             next_candidates(num_next_candidates - 1)%start = candidate%start
             next_candidates(num_next_candidates - 1)%end_ = midpoint
             ! Right half.
             next_candidates(num_next_candidates)%start = midpoint
             next_candidates(num_next_candidates)%end_ = candidate%end_

             ! Allocate the new nodes and call sub-divide.
             allocate(next_candidates(num_next_candidates - 1)%nodes( &
                  num_nodes, dimension_))
             allocate(next_candidates(num_next_candidates)%nodes( &
                  num_nodes, dimension_))
             call subdivide_nodes( &
                  num_nodes, dimension_, candidate%nodes, &
                  next_candidates(num_next_candidates - 1)%nodes, &
                  next_candidates(num_next_candidates)%nodes)
          end if
       end do

       ! NOTE: This may copy empty slots, but this is OK since we track
       !       `num_candidates` separately.
       call move_alloc(next_candidates, candidates)
       num_candidates = num_next_candidates

       ! If there are no more candidates, we are done.
       if (num_candidates == 0) then
          return
       end if

    end do

    ! Compute the s-parameter as the mean of the **start** and
    ! **end** parameters.
    allocate(s_params(2 * num_candidates))
    s_params(:num_candidates) = candidates(:num_candidates)%start
    s_params(num_candidates + 1:) = candidates(:num_candidates)%end_
    s_approx = sum(s_params) / (2 * num_candidates)

    std_dev = sqrt(sum((s_params - s_approx)**2) / (2 * num_candidates))
    if (std_dev > LOCATE_STD_CAP) then
       s_approx = -2.0_dp
       return
    end if

    ! NOTE: We use ``midpoint`` as a "placeholder" for the update.
    call newton_refine( &
         num_nodes, dimension_, nodes, point, s_approx, midpoint)
    s_approx = midpoint

  end subroutine locate_point

  subroutine elevate_nodes( &
       num_nodes, dimension_, nodes, elevated) &
       bind(c, name='elevate_nodes')

    integer(c_int), intent(in) :: num_nodes, dimension_
    real(c_double), intent(in) :: nodes(num_nodes, dimension_)
    real(c_double), intent(out) :: elevated(num_nodes + 1, dimension_)
    ! Variables outside of signature.
    integer(c_int) :: i

    elevated(1, :) = nodes(1, :)
    forall (i = 1:num_nodes)
       elevated(i + 1, :) = ( &
            i * nodes(i, :) + (num_nodes - i) * nodes(i + 1, :)) / num_nodes
    end forall
    elevated(num_nodes + 1, :) = nodes(num_nodes, :)

  end subroutine elevate_nodes

end module curve
