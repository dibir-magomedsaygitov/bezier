#########################
curve_intersection module
#########################

.. |eacute| unicode:: U+000E9 .. LATIN SMALL LETTER E WITH ACUTE
   :trim:

This is a collection of procedures and types for computing intersections
between two B |eacute| zier curves in :math:`\mathbf{R}^2`.

**********
Procedures
**********

.. c:function:: void BEZ_bbox_intersect(const int *num_nodes1, \
                                        const double *nodes1, \
                                        const int *num_nodes2, \
                                        const double *nodes2, \
                                        BoxIntersectionType *enum_)

   Determine how the bounding boxes of two B |eacute| zier curves intersect.

   :param num_nodes1:
      **[Input]** The number of control points :math:`N_1` of the first
      B |eacute| zier curve.
   :type num_nodes1: :c:expr:`const int*`
   :param nodes1:
      **[Input]** The actual control points of the first curve as a
      :math:`2 \times N_1` array. This should be laid out in Fortran order,
      with :math:`2 N_1` total values.
   :type nodes1: :c:expr:`const double*`
   :param num_nodes2:
      **[Input]** The number of control points :math:`N_2` of the second
      B |eacute| zier curve.
   :type num_nodes2: :c:expr:`const int*`
   :param nodes2:
      **[Input]** The actual control points of the second curve as a
      :math:`2 \times N_2` array. This should be laid out in Fortran order,
      with :math:`2 N_2` total values.
   :type nodes2: :c:expr:`const double*`
   :param enum_:
      **[Output]** The type of intersection between the bounding boxes of the
      two curves.
   :type enum_: :c:expr:`BoxIntersectionType*`

   **Signature:**

   .. code-block:: c

      void
      BEZ_bbox_intersect(const int *num_nodes1,
                         const double *nodes1,
                         const int *num_nodes2,
                         const double *nodes2,
                         BoxIntersectionType *enum_);

.. c:function:: void BEZ_curve_intersections(const int *num_nodes_first, \
                                             const double *nodes_first, \
                                             const int *num_nodes_second, \
                                             const double *nodes_second, \
                                             const int *intersections_size, \
                                             double *intersections, \
                                             int *num_intersections, \
                                             bool *coincident, \
                                             Status *status)

   Compute the intersection points of two B |eacute| zier curves in
   :math:`\mathbf{R}^2`. Does so by subdividing each curve in half and
   rejecting any pairs that don't have overlapping bounding boxes. Once each
   subdivided segment is close enough to a line, this uses Newton's method
   to compute an accurate intersection.

   Each returned intersection point will be a pair :math:`(s, t)` of the
   parameters that produced the intersection :math:`B_1(s) = B_2(t)`.

   .. tip::

      If the ``status`` returned is :c:data:`INSUFFICIENT_SPACE` that means
      ``intersections_size`` is smaller than ``num_intersections``. In that
      case, ``intersections`` needs to be resized and the procedure must
      be invoked again.

      To avoid false starts occurring on a regular basis, keep a static
      workspace around that will continue to grow as resizing is needed, but
      will never shrink.

      Failed invocations can be avoided altogether if B |eacute| zout's
      theorem is used to determine the maximum number of intersections.

   :param num_nodes_first:
      **[Input]** The number of control points :math:`N_1` of the first
      B |eacute| zier curve.
   :type num_nodes_first: :c:expr:`const int*`
   :param nodes_first:
      **[Input]** The actual control points of the first curve as a
      :math:`2 \times N_1` array. This should be laid out in Fortran order,
      with :math:`2 N_1` total values.
   :type nodes_first: :c:expr:`const double*`
   :param num_nodes_second:
      **[Input]** The number of control points :math:`N_2` of the second
      B |eacute| zier curve.
   :type num_nodes_second: :c:expr:`const int*`
   :param nodes_second:
      **[Input]** The actual control points of the second curve as a
      :math:`2 \times N_2` array. This should be laid out in Fortran order,
      with :math:`2 N_2` total values.
   :type nodes_second: :c:expr:`const double*`
   :param intersections_size:
      **[Input]** The size :math:`S` of ``intersections``, which must be
      pre-allocated by the caller. By B |eacute| zout's theorem, a hard upper
      bound is :math:`S \leq (N_1 - 1)(N_2 - 1)` (since the degree of each
      curve is one less than the number of control points).
   :type intersections_size: :c:expr:`const int*`
   :param intersections:
      **[Output]** The pairs of intersection points, as a :math:`2 \times S`
      array laid out in Fortran order. The first ``num_intersections``
      columns of ``intersections`` will be populated (unless the array is
      too small).
   :type intersections: :c:expr:`int*`
   :param num_intersections:
      **[Output]** The number of intersections found.
   :type num_intersections: :c:expr:`int*`
   :param coincident:
      **[Output]** Flag indicating if the curves are coincident segments on
      the same algebraic curve. If they are, then ``intersections`` will
      contain two points: the beginning and end of the overlapping segment
      common to both curves.
   :type coincident: :c:expr:`bool*`
   :param status:
      **[Output]** The status code for the procedure. Will be

      * :c:data:`SUCCESS` on success.
      * :c:data:`INSUFFICIENT_SPACE` if ``intersections_size`` is smaller than
        ``num_intersections``.
      * :c:data:`NO_CONVERGE` if the curves don't converge to approximately
        linear after being subdivided 20 times.
      * An integer :math:`N_C \geq 64` to indicate that there were :math:`N_C`
        pairs of candidate segments that had overlapping convex hulls. This is
        a sign of either round-off error in detecting that the curves are
        coincident or that the intersection is a non-simple root.
      * :c:data:`BAD_MULTIPLICITY` if the curves have an intersection that
        doesn't converge to either a simple or double root via Newton's method.
   :type status: :c:expr:`Status*`

   **Signature:**

   .. code-block:: c

      void
      BEZ_curve_intersections(const int *num_nodes_first,
                              const double *nodes_first,
                              const int *num_nodes_second,
                              const double *nodes_second,
                              const int *intersections_size,
                              double *intersections,
                              int *num_intersections,
                              bool *coincident,
                              Status *status);

.. c:function:: void BEZ_newton_refine_curve_intersect(const double *s, \
                                                       const int *num_nodes1, \
                                                       const double *nodes1, \
                                                       const double *t, \
                                                       const int *num_nodes2, \
                                                       const double *nodes2, \
                                                       double *new_s, \
                                                       double *new_t, \
                                                       Status *status)

   This refines a solution to :math:`F(s, t) = B_1(s) - B_2(t)` using Newton's
   method. Given a current approximation :math:`(s_n, t_n)` for a solution,
   this produces the updated approximation via

   .. math::

      \left[\begin{array}{c} s_{n + 1} \\ t_{n + 1} \end{array}\right] =
      \left[\begin{array}{c} s_n \\ t_n \end{array}\right] -
      DF(s_n, t_n)^{-1} F(s_n, t_n).

   :param s:
      **[Input]** The first parameter :math:`s_n` of the current approximation
      of a solution.
   :type s: :c:expr:`const double*`
   :param num_nodes1:
      **[Input]** The number of control points :math:`N_1` of the first
      B |eacute| zier curve.
   :type num_nodes1: :c:expr:`const int*`
   :param nodes1:
      **[Input]** The actual control points of the first curve as a
      :math:`2 \times N_1` array. This should be laid out in Fortran order,
      with :math:`2 N_1` total values.
   :type nodes1: :c:expr:`const double*`
   :param t:
      **[Input]** The second parameter :math:`t_n` of the current approximation
      of a solution.
   :type t: :c:expr:`const double*`
   :param num_nodes2:
      **[Input]** The number of control points :math:`N_2` of the second
      B |eacute| zier curve.
   :type num_nodes2: :c:expr:`const int*`
   :param nodes2:
      **[Input]** The actual control points of the second curve as a
      :math:`2 \times N_2` array. This should be laid out in Fortran order,
      with :math:`2 N_2` total values.
   :type nodes2: :c:expr:`const double*`
   :param new_s:
      **[Output]** The first parameter :math:`s_{n + 1}` of the updated
      approximation.
   :type new_s: :c:expr:`double*`
   :param new_t:
      **[Output]** The second parameter :math:`t_{n + 1}` of the updated
      approximation.
   :type new_t: :c:expr:`double*`
   :param status:
      **[Output]** The status code for the procedure. Will be

      * :c:data:`SUCCESS` on success.
      * :c:data:`SINGULAR` if the computed Jacobian :math:`DF(s_n, t_n)` is
        singular to numerical precision.
   :type status: :c:expr:`Status*`

   **Signature:**

   .. code-block:: c

      void
      BEZ_newton_refine_curve_intersect(const double *s,
                                        const int *num_nodes1,
                                        const double *nodes1,
                                        const double *t,
                                        const int *num_nodes2,
                                        const double *nodes2,
                                        double *new_s,
                                        double *new_t,
                                        Status *status);

.. c:function:: void BEZ_free_curve_intersections_workspace(void)

   This frees any long-lived workspace(s) used by ``libbezier`` throughout
   the life of a program. It should be called during clean-up for any code
   which invokes :c:func:`BEZ_curve_intersections`.

   **Signature:**

   .. code-block:: c

      void
      BEZ_free_curve_intersections_workspace(void);

*****
Types
*****

.. c:enum:: BoxIntersectionType

   This enum is used to indicate how the bounding boxes of two B |eacute| zier
   curves intersect.

   .. c:enumerator:: INTERSECTION

      (``0``)
      The bounding boxes intersect in a rectangle with positive area.

   .. c:enumerator:: TANGENT

      (``1``)
      The bounding boxes are tangent, i.e. they intersect at a single point
      or along an edge and the region of intersection has zero area.

   .. c:enumerator:: DISJOINT

      (``2``)
      The bounding boxes do not touch at any point.
